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

### Xcode Project
- Uses `PBXFileSystemSynchronizedRootGroup` — new Swift files in `meter-reading-recorder/` are automatically included in the build without editing `project.pbxproj`
- Swift 5.0, iOS deployment target 26.2
