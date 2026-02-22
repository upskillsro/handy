# ReminderHelper

A native macOS companion app for Apple Reminders, designed for focus and speed.

## Features
- **Side Strip Interface**: Minimal UI that lives on your desktop.
- **Estimated Durations**: localized estimate storage (persists even if Reminders app doesn't support it natively).
- **Focus Timer**: Draggable floating pill overlay for active tasks.
- **Bi-directional Sync**: Updates functionality syncs with Apple Reminders.
- **Focus Mode**: Filter your list to just the active task.

## Setup & Requirements

### 1. Open in Xcode
The easiest way to run this is to open the `Package.swift` folder in Xcode.
1. Open Xcode.
2. Select **File > Open** and choose the `ReminderHelper` directory (containing `Package.swift`).
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
- Select the `ReminderHelper` scheme.
- Press `Cmd+R`.
- **Grant Access**: When prompted, allow access to Reminders. The app requires this to function.

## Usage
- **Toggle Window**: Click the menu bar icon (checkmark circle) to toggle the side strip.
- **Add Task**: Type in the quick add box at the bottom (supports basic titles).
- **Estimate**: Hover over a task and click the small duration pill (or "Set Est.") to add a time estimate.
- **Start Timer**: Click the Play button on a task row.
- **Focus Mode**: Click "Focus mode" at the bottom to hide inactive tasks.
- **Complete**: Click the circle to complete a reminder.

## Architecture
- **SwiftData**: Used for storing estimates (`EstimateStore.swift`).
- **EventKit**: Used for Reminder sync (`RemindersService.swift`).
- **SwiftUI**: Pure SwiftUI views wrapped in `NSHostingView` within `NSPanel` for window management.
