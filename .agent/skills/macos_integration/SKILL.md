---
name: macOS Integration
description: Specific guidelines for macOS application development, including permissions, window management, and menu bar extras.
---

# macOS Integration Guidelines

## Permissions & Entitlements
- **Sandboxing**: The app is sandboxed. Ensure `com.apple.security.app-sandbox` is true.
- **Privacy Keys**: `Info.plist` MUST contain usage descriptions for all requested permissions (e.g., `NSRemindersUsageDescription`).
- **Hardened Runtime**: Required for notarization.

## Window Management
- **Menu Bar App**: This is a menu bar utility. `LSUIElement` is set to `true` in `Info.plist` to hide the dock icon.
- **Floating Windows**: Use `NSPanel` or `NSWindow` with appropriate levels (e.g., `.floating`, `.mainMenu`) for overlays.
- **Activation**: Use `NSApp.activate(ignoringOtherApps: true)` to bring windows to front when needed.

## System Integration
- **EventKit**: Used for Reminders. Handle initialization asynchronously and respect user privacy settings.
- **Launch on Login**: Use `SMAppService` or legacy helper apps if required (not currently implemented).
- **Shortcuts**: Global hotkeys can be managed via `CGEvent` or libraries like `HotKey`; ensure they don't conflict with system defaults.
