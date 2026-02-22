---
description: Rebuild and restart the Reminder Helper application
---

1. Kill any running instances of the application
   `pkill -f "ReminderHelper" || true`

2. Rebuild the application package
   `./package_app.sh`

3. Launch the new application bundle
   `open "Reminder Helper.app"`
