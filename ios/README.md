# Forklore (iOS)

The SwiftUI app. It needs Xcode with the iOS 26.5 SDK, and a device with Apple
Intelligence for on-device insights.

## Run it

1. Open `ios/PersonalOSHealth.xcodeproj` in Xcode.
2. Pick your iPhone as the run destination and press Run (⌘R).
3. Go through onboarding and allow Health access when asked.

The app talks straight to Convex. The deployment URL, and the privacy and terms
links, are in `PersonalOSHealth/AppConfig.swift`. There is no local server to run.

To test purchases without the App Store, choose `PersonalOSHealth/Products.storekit`
under the scheme's Run options, StoreKit Configuration.
