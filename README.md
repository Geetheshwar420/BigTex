# BigText Minimal App

This repository contains a single-file Flutter app at `main.dart` that demonstrates a full-screen, borderless `TextField` with tap-to-clear placeholder behavior and pinch-to-zoom font scaling.

Key details:

- Single-file app: `main.dart` (in the project root)
- Minimal dependencies: only `flutter` SDK
- Memory-conscious: no assets, no extra packages, only a single `TextEditingController` and `FocusNode`.

Quick start (requires Flutter SDK installed):

```bash
flutter pub get
flutter run
```

Notes:

- If you want to target a specific device, use `flutter run -d <device-id>`.
- The default font size is 70.0, clamped to the 30.0–200.0 range during pinch gestures.

iOS build instructions (macOS required)

1. Prerequisites:
	- A macOS machine with Xcode installed and command-line tools configured.
	- An Apple Developer account and a provisioning profile or automatic signing set up in Xcode.

2. Basic automated build (recommended when signing is configured):

```bash
flutter pub get
flutter build ipa --export-options-plist=ios/export_options.plist
```

3. Manual Xcode archive (useful for code signing configuration):

```bash
flutter pub get
flutter build ios --release
open ios/Runner.xcworkspace
# In Xcode: select a Generic iOS Device, then Product → Archive, then Distribute App
```

4. Notes on signing:
	- Open `ios/Runner.xcworkspace` in Xcode, select the Runner target, and set the Team under Signing & Capabilities.
	- If you use the automated `flutter build ipa` flow, edit `ios/export_options.plist` and set `method` and `teamID` appropriately.

If you want, provide your Apple Team ID and desired export `method` and I can pre-fill `ios/export_options.plist` accordingly. I cannot produce an iOS binary from this Windows host — you must run the build commands on macOS or provide macOS access.
