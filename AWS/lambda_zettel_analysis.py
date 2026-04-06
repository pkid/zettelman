import json
import os
import re
import traceback
from datetime import datetime
from typing import Any
from urllib.parse import unquote_plus

import boto3

s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime")

MODEL_ID = os.environ.get("MODEL_ID", "mistral.pixtral-large-2502-v1:0")
DEFAULT_BUCKET = os.environ.get("BUCKET_NAME", "zettelman")


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    try:
        print(f"Received event (truncated): {json.dumps(event)[:2000]}")
        if is_s3_event(event):
            return handle_s3_trigger(event)
        if is_eventbridge_s3_event(event):
            return handle_eventbridge_s3_trigger(event)
        return handle_direct_request(event)
    except Exception as error:
        print(f"Unhandled error: {error}")
        print(traceback.format_exc())
        return response(500, {"error": str(error)})


def is_s3_event(event: dict[str, Any]) -> bool:
    records = event.get("Records")
    if not isinstance(records, list) or not records:
        return False
    return records[0].get("eventSource") == "aws:s3"


def is_eventbridge_s3_event(event: dict[str, Any]) -> bool:
    return event.get("source") == "aws.s3" and isinstance(event.get("detail"), dict)


def handle_s3_trigger(event: dict[str, Any]) -> dict[str, Any]:
    processed = 0
    skipped = 0
    errors: list[str] = []

    for record in event.get("Records", []):
        try:
            bucket = record["s3"]["bucket"]["name"]
            s3_key = unquote_plus(record["s3"]["object"]["key"])
        except Exception:
            print(f"Skipping record with unexpected shape: {record}")
            skipped += 1
            continue

        if "received/" not in s3_key:
            print(f"Skipping key outside received/: {s3_key}")
            skipped += 1
            continue

        if not is_supported_image(s3_key):
            print(f"Skipping unsupported image type: {s3_key}")
            skipped += 1
            continue

        try:
            print(f"Processing s3://{bucket}/{s3_key}")
            object_bytes = download_object(bucket, s3_key)
            media_type = guess_media_type(s3_key)
            model_result = analyze_with_model(object_bytes, media_type)
            analysis_key = analysis_output_key(s3_key)
            upload_analysis(bucket, analysis_key, {"source_key": s3_key, **model_result})
            processed += 1
            print(f"Analysis written to s3://{bucket}/{analysis_key}")
        except Exception as error:
            message = f"{s3_key}: {error}"
            print(f"Failed to process {message}")
            print(traceback.format_exc())
            errors.append(message)

    print(f"S3 trigger summary: processed={processed}, skipped={skipped}, errors={len(errors)}")
    return {"status": "ok", "processed": processed, "skipped": skipped, "errors": errors}


def handle_eventbridge_s3_trigger(event: dict[str, Any]) -> dict[str, Any]:
    detail = event.get("detail", {})
    try:
        bucket = detail["bucket"]["name"]
        s3_key = unquote_plus(detail["object"]["key"])
    except Exception:
        print(f"EventBridge S3 detail missing expected fields: {detail}")
        return {"status": "ok", "processed": 0, "skipped": 1, "errors": ["invalid_eventbridge_shape"]}

    wrapped_event = {
        "Records": [
            {
                "eventSource": "aws:s3",
                "s3": {
                    "bucket": {"name": bucket},
                    "object": {"key": s3_key},
                },
            }
        ]
    }
    return handle_s3_trigger(wrapped_event)


def handle_direct_request(event: dict[str, Any]) -> dict[str, Any]:
    body = parse_event_body(event)
    s3_key = body.get("s3Key")
    bucket = body.get("bucket") or DEFAULT_BUCKET

    if not bucket:
        return response(400, {"error": "Missing bucket. Set BUCKET_NAME or send bucket in the request."})

    if not s3_key:
        return response(400, {"error": "Missing required field: s3Key"})

    object_bytes = download_object(bucket, s3_key)
    media_type = guess_media_type(s3_key)
    model_result = analyze_with_model(object_bytes, media_type)

    return response(200, model_result)


def parse_event_body(event: dict[str, Any]) -> dict[str, Any]:
    raw_body = event.get("body")

    if raw_body is None:
        return event

    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    if isinstance(raw_body, dict):
        return raw_body

    return json.loads(raw_body)


def download_object(bucket: str, key: str) -> bytes:
    print(f"Downloading s3://{bucket}/{key}")
    result = s3_client.get_object(Bucket=bucket, Key=key)
    return result["Body"].read()


def guess_media_type(key: str) -> str:
    lowered = key.lower()

    if lowered.endswith(".png"):
        return "image/png"
    if lowered.endswith(".webp"):
        return "image/webp"

    return "image/jpeg"


def is_supported_image(key: str) -> bool:
    lowered = key.lower()
    return lowered.endswith(".jpg") or lowered.endswith(".jpeg") or lowered.endswith(".png") or lowered.endswith(".webp")


def analysis_output_key(source_key: str) -> str:
    processed = source_key.replace("received/", "processed/", 1)
    base, _ = os.path.splitext(processed)
    return f"{base}.analysis.json"


def upload_analysis(bucket: str, key: str, payload: dict[str, Any]) -> None:
    s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(payload).encode("utf-8"),
        ContentType="application/json",
    )


def image_format_from_media_type(media_type: str) -> str:
    if media_type == "image/png":
        return "png"
    if media_type == "image/webp":
        return "webp"
    return "jpeg"


def analyze_with_model(object_bytes: bytes, media_type: str) -> dict[str, Any]:
    prompt = """
You are analyzing an appointment zettel, usually in German (sometimes English or mixed German/English).

Extract exactly these fields:
- date_time: ISO 8601 date-time string if the appointment date AND time are clear, otherwise null
- what: very short summary in at most 5 words
- where: location text. If a detailed address is visible, include full details (name + street + postal code + city)
- with_whom: person this appointment is with (for example doctor last name), or empty string if missing
- confidence: number from 0.0 to 1.0

Rules:
- Do not invent details that are not visible.
- Read handwritten digits carefully and digit-by-digit (for example distinguish 7 vs 9).
- If only a date is visible but no time is visible, set date_time to null.
- Keep "what" short and concrete.
- For "with_whom", prefer explicit person names/titles from the zettel (for example "Dr. Mueller").
- For "where", keep all meaningful location/address details visible on the zettel.
- Correctly interpret common German date/time patterns, for example:
  - 21.03.2026
  - 21.3.26
  - 28. Maerz 2026
  - 28. März 2026
  - 14:30 Uhr
  - 14.30
- Convert extracted date/time into ISO 8601 format (YYYY-MM-DDTHH:MM:SS).
- Preserve the original language for "what" and "where" (do not translate).
- Return valid JSON only.

Example:
{"date_time":"2026-03-28T09:30:00","what":"Dermatology follow-up","where":"City Clinic, Hauptstrasse 12, 80331 Muenchen","with_whom":"Dr. Mueller","confidence":0.88}
""".strip()

    response = bedrock_runtime.converse(
        modelId=MODEL_ID,
        messages=[
            {
                "role": "user",
                "content": [
                    {"text": prompt},
                    {
                        "image": {
                            "format": image_format_from_media_type(media_type),
                            "source": {"bytes": object_bytes},
                        }
                    },
                ],
            }
        ],
        inferenceConfig={"maxTokens": 512},
    )
    output = response.get("output", {})
    message = output.get("message", {})
    content = message.get("content", [])
    raw_text = next((part.get("text", "") for part in content if isinstance(part, dict) and "text" in part), "")
    if not raw_text:
        raise ValueError(f"Model did not return text content: {json.dumps(response)}")

    parsed = parse_model_json(raw_text)
    normalized = normalize_date_time(parsed.get("date_time"))

    return {
        "date_time": normalized,
        "what": normalize_what(parsed.get("what", "")),
        "where": (parsed.get("where") or "").strip(),
        "with_whom": normalize_with_whom(parsed.get("with_whom", "")),
        "confidence": parsed.get("confidence"),
    }


def parse_model_json(raw_text: str) -> dict[str, Any]:
    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", raw_text, re.DOTALL)
        if not match:
            raise ValueError(f"Claude did not return JSON: {raw_text}")
        return json.loads(match.group(0))


def normalize_what(value: str) -> str:
    cleaned = " ".join((value or "").strip().split())
    words = cleaned.split(" ")
    limited = " ".join(words[:5]).strip()
    return limited or "Review appointment"


def normalize_with_whom(value: str) -> str:
    return " ".join((value or "").strip().split())


def normalize_date_time(value: Any) -> str | None:
    if not value or not isinstance(value, str):
        return None

    cleaned = value.strip()
    if not cleaned:
        return None

    try:
        dt = datetime.fromisoformat(cleaned.replace("Z", "+00:00"))
        return dt.replace(tzinfo=None).strftime("%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return None


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,x-api-key",
            "Access-Control-Allow-Methods": "OPTIONS,POST",
        },
        "body": json.dumps(body),
    }
