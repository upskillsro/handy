---
name: Swift and SwiftUI Development
description: Best practices for writing clean, efficient, and maintainable Swift and SwiftUI code for this project.
---

# Swift and SwiftUI Development Guidelines

## Architecture
- **MVVM Pattern**: Use Model-View-ViewModel. Views should observe `ObservableObject` ViewModels.
- **Services**: Encapsulate logic in Service classes (e.g., `RemindersService`, `TimerService`).
- **Dependency Injection**: Pass dependencies via `environmentObject` or initializer injection where possible.

## SwiftUI Best Practices
- **Small Views**: Break down complex views into smaller `struct` components.
- **State Management**: Use `@State` for local UI state, `@ObservedObject` or `@EnvironmentObject` for shared state.
- **Identifiers**: Ensure lists and `ForEach` loops use stable `id`s (e.g., `calendarItemIdentifier` for Reminders).
- **Previews**: Maintain previews for UI components to speed up development.

## Code Style
- **Naming**: camelCase for variables/functions, PascalCase for types.
- **SwiftLint**: Adhere to standard Swift linting rules (if applied).
- **Extensions**: Use extensions to organize code and add functionality to existing types.
