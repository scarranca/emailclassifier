# Cove 0.1.18

- Corrected missing `com.apple.security.personal-information.location` entitlement in hardened-runtime signing. The packaging script verifies that the signed app contains it. Location usage strings were already present.
- Location lookup checks system availability, reuses only a recent valid fix, tolerates transient `locationUnknown`, and bounds active updates to 20 seconds after authorization. City search has a 15-second timeout and cancellation/request identity guards.
- Weather has an always-accessible city entry path, specific loading phases, and Cancel. A failed location lookup can recover through city lookup without location permission.
- Apple geocoding of the user-provided city “San Francisco California” succeeded locally in 0.17 seconds. Automated fixtures verify location-failure recovery, rounded coordinates, saved city restoration, and cancellation/late-result rejection. This does not establish live device-location success.
- Two isolated typography reviews (semantic and mechanical) informed Home-only type tokens. The web-oriented detector reported no findings but does not validate native SwiftUI; native source and rendered screenshots were reviewed separately.
- Home renders at 720 and 1100 points with bundled Inter registered, a pending calendar invitation, a priority email, Weather, and the Undo notification. Captures are adjacent.
- Full suite: 300 passed; 3 opt-in live checks skipped. Refreshed native rendering capture passed separately after adding a visible-priority fixture.
- No real email or calendar mutations were performed during QA.

- Universal release installed at `/Applications/Cove.app`, version 0.1.18 build 20. Strict signing and the installed location entitlement verified. Native Home inspected with the user's saved San Francisco forecast; a new device-location fix was not verified.
- App notarization accepted: `680c468d-e345-41ab-9334-3fa55086eba0`. DMG notarization accepted: `18d0aa95-91de-4bd6-8a55-f0bc34203d7d`. Both tickets stapled; final DMG passed image verification and Gatekeeper assessment.
- Final release: `dist/releases/Cove-0.1.18.dmg`; SHA-256 `7818acc22140ab6165c0eeb5ab5a6b9a3c0ce022d99d92ce808301ea751fbfa4`.
- Website release updated and deployed (`75f6aa62-62f2-4c5c-ba5d-3aa6d9a69579`). Public beta page shows 0.1.18; `/download/latest` resolves to the new DMG and its downloaded SHA-256 matches the final installer.
