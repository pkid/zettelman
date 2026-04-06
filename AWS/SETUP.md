# Zettelman AWS Setup

This app follows the same architecture as `trip-manager`:

1. Cognito User Pool for sign-in/sign-up
2. Cognito Identity Pool for temporary AWS credentials
3. S3 for private zettel image storage and appointment manifest storage
4. Lambda using Bedrock vision model for image analysis

## 1. Cognito and S3

Use the same Amplify package setup as the reference app, but point it at your own AWS resources.

- Update [amplifyconfiguration.json](/Users/yashu/Repos/zettelman/Zettelman/amplifyconfiguration.json)
- Replace:
  - `YOUR-IDENTITY-POOL-ID`
  - `YOUR-USER-POOL-ID`
  - `YOUR-APP-CLIENT-ID`
  - `YOUR-S3-BUCKET`

The app stores files under:

- Original uploads: `received/{email}/zettels/{timestamp}-{id}.jpg`
- Appointment manifest: `appointments/{email}/appointments.json`

## 2. Lambda

Deploy [lambda_zettel_analysis.py](/Users/yashu/Repos/zettelman/AWS/lambda_zettel_analysis.py) as a Python Lambda.

Required environment variables:

- `BUCKET_NAME`: optional; defaults to `zettelman`
- `MODEL_ID`: optional; defaults to `mistral.pixtral-large-2502-v1:0`

Required IAM permissions for the Lambda role:

- `s3:GetObject` on the uploads bucket
- `s3:PutObject` on the processed output prefix
- `bedrock:Converse` (or broader `bedrock:InvokeModel`) for the Bedrock model you choose

Configure an S3 trigger on the same bucket (`zettelman`) for this Lambda:

- Event type: `ObjectCreated` (at least `PUT`)
- Prefix: `received/`
- Suffix: one trigger per image type (`.jpg`, `.jpeg`, `.png`, `.webp`) or no suffix if you filter in code

For each uploaded zettel:

1. Input image: `received/{email}/zettels/{id}.jpg`
2. Lambda writes analysis JSON: `processed/{email}/zettels/{id}.analysis.json`

Example output JSON content:

```json
{
  "source_key": "received/yashu_at_example_com/zettels/260321101530-a1b2c3d4.jpg",
  "date_time": "2026-03-28T09:30:00",
  "what": "Dermatology follow-up",
  "where": "City Clinic, Hauptstrasse 12, 80331 Muenchen",
  "with_whom": "Dr. Mueller",
  "confidence": 0.88
}
```

## 3. User Flow

Once configured, the app flow is:

1. User signs in with Cognito
2. App uploads the zettel image to S3 using Amplify Storage
3. S3 trigger invokes Lambda automatically
4. Lambda reads the image and writes analysis JSON to `processed/{email}/zettels/...analysis.json`
5. App polls S3 for that analysis file and then shows a confirmation sheet
6. App saves the confirmed appointment locally and uploads the manifest JSON to S3
