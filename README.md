# Meter Reading Recorder App for iOS
[![iOS CI](https://github.com/mantheij/meter-reading-recorder/actions/workflows/ci.yml/badge.svg)](https://github.com/mantheij/meter-reading-recorder/actions/workflows/ci.yml)

(WIP) App for recording meter readings for energy, water and gas consumption in a household.

## Setup

1. Clone the repository
2. Download `GoogleService-Info.plist` from the [Firebase Console](https://console.firebase.google.com/) for the `meter-reading-recorder` project
3. Place the file in `meter-reading-recorder/GoogleService-Info.plist` (this file is gitignored)
4. Activate the pre-commit hook to prevent accidental secret leaks:
   ```bash
   git config core.hooksPath .githooks
   ```
5. Open `meter-reading-recorder.xcodeproj` in Xcode and build

## Record Meter Readings manually or by Camera, Visualize your Consumption
<img width="388.8" height="583.2" alt="979_1x_shots_so" src="https://github.com/user-attachments/assets/b26ece7e-9adb-4870-8be1-3eb5c9362f52" />
<img width="388.8" height="583.2" alt="380_1x_shots_so" src="https://github.com/user-attachments/assets/06a6a9b9-7932-4ab9-b4e4-34b426b41e81" />
