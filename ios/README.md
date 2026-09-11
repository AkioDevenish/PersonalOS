# PersonalOSHealth (iOS)

## Open in Xcode

```bash
open ~/personal_os/ios/PersonalOSHealth/PersonalOSHealth.xcodeproj
```

## Run on iPhone

1. Plug in iPhone → select it as run destination → **Run** (⌘R)
2. **Server URL:** `http://192.168.100.252:3000` (your Mac Wi‑Fi IP)
3. **Ingest token:** value from `web/.env.local` → `HEALTH_INGEST_SECRET`
4. **Request Health access** → **Sync today to hub**

Mac hub must be running: `cd ~/personal_os/web && npm run dev`
