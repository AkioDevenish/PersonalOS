# SaaS AI Runtime

The Well-Being product supports three Gemma 4 modes.

## Included Device Package

Set:

```env
AI_RUNTIME_MODE=included_device
INCLUDED_DEVICE_MODEL_PACKAGE=com.personal-os.gemma4-health
```

In this mode, the SaaS does not spend server tokens for health reports. The iOS app downloads or ships with the included Gemma package, runs analysis locally, then uploads the finished report to:

```txt
POST /api/well-being/device-report
```

The app can discover the package manifest at:

```txt
GET /api/well-being/model-package
```

This is the privacy-first/default package model.

## Paid Token Mode

Set:

```env
AI_RUNTIME_MODE=paid_token
GEMMA_URL=https://your-provider.example/v1/generate
GEMMA_API_KEY=...
```

This is for paid cloud inference where the platform pays or the user brings tokens.

## Server Gemma Mode

Set:

```env
AI_RUNTIME_MODE=server_gemma
GEMMA_URL=http://127.0.0.1:11434/api/generate
GEMMA_MODEL=gemma4
```

This keeps the current local Ollama-style development flow.
