# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
# Build (use an available simulator from `xcrun simctl list devices available`)
xcodebuild -scheme meter-reading-recorder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# CI build (no specific simulator)
xcodebuild -scheme meter-reading-recorder -sdk iphonesimulator build
```

Tests exist in `meter-reading-recorderTests/` (Swift Testing) and `meter-reading-recorderUITests/` (XCTest) but are currently placeholder stubs.

## Architecture

**iOS app (SwiftUI + Core Data)** for recording household meter readings (water, electricity, gas) via camera OCR or manual entry.

### Data Layer
- **Core Data** with `MeterReading` entity (id, value, meterType, date, imageData)
- `Persistence.swift` configures `NSPersistentContainer`; supports in-memory stores for testing
- `MeterType` enum (`water`, `electricity`, `gas`) — raw values stored as strings in Core Data

### Navigation & UI Structure
- `meter_reading_recorderApp.swift` → `ContentView` (root) → `MeterTypeListView` (home screen)
- `SidebarView` provides slide-out drawer navigation using `SidebarDestination` enum for routing
- Navigation uses `NavigationStack` with `NavigationPath` for programmatic navigation from sidebar

### Key Services
- `OCRService` — Vision framework text recognition on camera-captured images
- `CameraView` — `UIImagePickerController` wrapped as `UIViewControllerRepresentable`
- `ValueFormatter` — sanitizes meter reading input (comma→dot, strips non-numeric)

### Theming & Localization
- `Theme.swift` — `AppTheme` enum with spacing tokens, radii, adaptive colors, and reusable components (`MeterCard`, `PrimaryButton`, `MeterReadingFormSheet`, `EmptyStateView`)
- `Localization.swift` — `L10n` struct reads `@AppStorage("appLanguage")` from UserDefaults; all UI strings go through `L10n.*` static properties (DE/EN)
- `AppearanceManager.swift` — `AppAppearance` enum (system/light/dark) persisted via `@AppStorage("appAppearance")`; applied as `.preferredColorScheme()` on the root WindowGroup

### Firebase Configuration
- `GoogleService-Info.plist` is **not checked into Git** — it contains API keys and is listed in `.gitignore`
- A template with placeholder values exists at `meter-reading-recorder/GoogleService-Info.plist.template`
- **Local development:** Download `GoogleService-Info.plist` from the Firebase Console and place it in `meter-reading-recorder/`
- **CI:** The plist is injected from the GitHub Secret `GOOGLE_SERVICE_INFO_PLIST` (base64-encoded) during the build workflow
- A pre-commit hook in `.githooks/` prevents accidental commits of secret files — activate it with: `git config core.hooksPath .githooks`

### Xcode Project
- Uses `PBXFileSystemSynchronizedRootGroup` — new Swift files in `meter-reading-recorder/` are automatically included in the build without editing `project.pbxproj`
- Swift 5.0, iOS deployment target 18.0
