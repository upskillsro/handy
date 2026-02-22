---
name: Performance Tuning
description: Guidelines for optimizing application performance and resource usage.
---

# Performance Tuning Guidelines

## CPU Usage
- **Idle Checks**: Regularly check Activity Monitor. Idle CPU usage should be near 0%.
- **Animations**: Avoid continuous animations (like Marquee) unless absolutely necessary. Use `timeline` or `CADisplayLink` carefully.
- **Timers**: Use `Timer.publish` on `RunLoop.main` or `DispatchSourceTimer` for periodic tasks, but stop them when not needed.

## Memory Management
- **Retain Cycles**: Watch out for `[weak self]` in closures, especially in `sink` or callbacks.
- **Image Handling**: Resize images/icons to display size to save memory.
- **Large Lists**: Use `LazyVStack` or `List` for displaying many reminders.

## Data Efficiency
- **EventKit Fetching**: Don't fetch all reminders every second. Use batch fetching or predicate-based fetching.
- **Background Threads**: Perform heavy sorting or logic on background queues (`DispatchQueue.global()`), update UI on `Main`.
- **Caching**: Cache expensive computations (like sort orders) where possible.
