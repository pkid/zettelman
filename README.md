# Zettelman

Zettelman is an iOS app that turns a photo of an appointment note ("zettel") into a structured appointment.

## What the app does

- Authenticates users with AWS Cognito (sign up, sign in, password reset).
- Lets users capture or select a zettel image.
- Uploads the image to S3 under the signed-in user namespace.
- Waits for an AWS Lambda + Bedrock vision analysis result in S3.
- Prefills appointment fields from the analysis (`what`, `where`, `with_whom`, `date_time`).
- Lets the user confirm/edit before saving.
- Stores appointments in an S3 JSON manifest and keeps a local cache for fast loading.
- Can add the appointment to iOS Calendar and schedule reminders.
- Enforces monthly upload quotas with StoreKit subscription plans.

## End-to-end flow

1. User signs in with Cognito.
2. User uploads a zettel image from camera or photo library.
3. App writes image to `received/{email}/zettels/...jpg` in S3.
4. S3 trigger invokes Lambda (`AWS/lambda_zettel_analysis.py`).
5. Lambda runs a Bedrock vision model and writes `processed/{email}/zettels/...analysis.json`.
6. App polls for the analysis file, builds a draft appointment, and shows a confirmation screen.
7. Confirmed appointments are saved locally and uploaded to `appointments/{email}/appointments.json`.

## Core modules

- `Zettelman/CognitoAuthManager.swift`: Cognito auth state and actions.
- `Zettelman/ZettelS3Service.swift`: S3 upload/download + per-user storage context.
- `Zettelman/ZettelAnalysisService.swift`: polling and parsing analysis output.
- `Zettelman/AppointmentStore.swift`: source of truth for appointments, reminders, calendar sync, upload quotas.
- `Zettelman/UploadSubscriptions.swift`: StoreKit plans and entitlement handling.
- `AWS/lambda_zettel_analysis.py`: image analysis Lambda logic.

## Requirements

- Xcode with iOS SDK support.
- AWS resources configured in `Zettelman/amplifyconfiguration.json` (Cognito, Identity Pool, S3).
- Lambda deployed and connected to S3 `ObjectCreated` events for the `received/` prefix.

See `AWS/SETUP.md` for backend setup details.
