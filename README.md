# Helpy

A native macOS companion app for Apple Reminders, designed for focus and speed.

## Features
- **Side Strip Interface**: Minimal UI that lives on your desktop.
- **Estimated Durations**: localized estimate storage (persists even if Reminders app doesn't support it natively).
- **Helpy Timer**: Draggable floating pill overlay for active tasks.
- **Bi-directional Sync**: Updates functionality syncs with Apple Reminders.
- **Focus Mode**: Filter your list to just the active task.
- **Local Assistant**: Type or record a voice note, transcribe it locally, and turn it into reviewable reminder drafts with Ollama.

## Setup & Requirements

### 1. Open in Xcode
The easiest way to run this is to open the `Package.swift` folder in Xcode.
1. Open Xcode.
2. Select **File > Open** and choose the `Helpy` directory (containing `Package.swift`).
3. Xcode will resolve package dependencies.

### 2. Configure Capabilities (Important)
For the app to access your Reminders, you must verify entitlements.
If you run it as a package, Xcode usually handles ad-hoc signing, but you may need to:
1. Go to the active target settings in Xcode.
2. Ensure the "Signing & Capabilities" tab includes **Reminders** access.
3. If creating an `.xcodeproj` manually:
   - Add `Privacy - Reminders Usage Description` key to `Info.plist`.
   - Add "Hardened Runtime" or "App Sandbox" with "Reminders" checked.
   - Entitlement: `com.apple.security.personal-information.calendars`

### 3. Build and Run
- Select the `Helpy` scheme.
- Press `Cmd+R`.
- **Grant Access**: When prompted, allow access to Reminders. The app requires this to function.

## Usage
- **Toggle Window**: Click the menu bar icon (checkmark circle) to toggle the side strip.
- **Add Task**: Type in the quick add box at the bottom (supports basic titles).
- **Assistant**: Click the waveform button in the quick add row to open the assistant panel.
- **Estimate**: Hover over a task and click the small duration pill (or "Set Est.") to add a time estimate.
- **Start Timer**: Click the Play button on a task row.
- **Focus Mode**: Click "Focus mode" at the bottom to hide inactive tasks.
- **Complete**: Click the circle to complete a reminder.

## Architecture
- **SwiftData**: Used for storing estimates (`EstimateStore.swift`).
- **EventKit**: Used for Reminder sync (`RemindersService.swift`).
- **SwiftUI**: Pure SwiftUI views wrapped in `NSHostingView` within `NSPanel` for window management.
- **Ollama**: Optional local task parsing for the assistant panel.
- **Local Transcription CLI**: Optional external whisper-compatible command for microphone transcription.

## Local Assistant Setup

1. Install Ollama from `https://ollama.com/download`.
2. Verify the CLI:
   ```bash
   ollama --version
   ```
3. Pull the default Helpy model:
   ```bash
   ollama pull qwen3.5:0.8b
   ```
4. Open Helpy settings and configure:
   - Ollama Base URL: `http://127.0.0.1:11434`
   - Ollama Model: `qwen3.5:0.8b`
5. If you want voice transcription, add a local Whisper-compatible command and args template using `{input}` as the audio-file placeholder.
6. Helpy can reuse read-only model files already downloaded by apps like Handy. Set the Transcription Model Path field or tap one of the detected shared-model presets in settings, then reference it with `{model}` in your transcription args template.
