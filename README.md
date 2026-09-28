# RemoteLove Native iOS — Milestone 1

This is the first fully native SwiftUI rebuild of the approved RemoteLove v47 experience. It does not use `WKWebView`, HTML, CSS or JavaScript.

## Requirements

- macOS with Xcode 14.3 or later
- iOS 16 or later

## Run the app

1. Open `RemoteLove.xcodeproj`.
2. Select the **RemoteLove** target.
3. Under **Signing & Capabilities**, select your Apple Developer Team when running on a physical device.
4. Select an iPhone simulator and press **Run** (⌘R).

The project uses marketing version `1.0` and build number `47`.

## Included native workflows

- Family sign-in, password-reset demonstration and helper invite-code access
- Independent care-recipient switching for Mum and Dad
- Role-based tabs: helpers cannot access family administration or the health dashboard
- Native Overview with independent All/Mum/Dad selection
- Care timeline, live completion, helper notification, Attending now and Done states
- Native task creation/editing, optional instructions, repeat choices and mass removal
- Medication supply, attention thresholds, active/paused schedules and editing
- Appointment creation, editing, cancellation, removal and three-day reminders
- Health recording prompts, age-aware references, category filters and native trend charts
- Care-circle invite codes, permissions and helper removal
- Updates, emergency acknowledgement, safety rules and complete activity history
- System, light and dark appearance options

## Demo access

- Select **Explore the family demo** on the login screen.
- Helper code for Mum: `LOVE2026`
- Helper code for Dad: `CARE4726`

Demo fixtures are isolated in `RemoteLove/DemoFixtures.swift`; they are not embedded in view code.

## Next production milestone

The screens and local interactions are native, but production authentication, encrypted cloud storage, multi-device synchronisation, secure photo upload and remote push notifications still require a backend. The `RemoteLoveStore` is intentionally the single state boundary so it can later be connected to those services without redesigning every screen.
