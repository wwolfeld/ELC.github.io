# Journal Tracker SwiftUI starter

This is a single-file SwiftUI starter for the journal app prototype.

## What it includes
- Native iPhone tab navigation for Program / Today / History
- Swipeable Program pages using SwiftUI `TabView` with `.page` style
- Daily journal form with four meal entries, exercise, water, and reflection
- Local persistence using `UserDefaults`
- CSV export for the current day using the iOS share sheet
- History screen that jumps back to a selected day

## What to do in Xcode
1. Create a new iOS App project in Xcode using SwiftUI.
2. Replace the default app/source file contents with `JournalTrackerApp.swift`.
3. Build and run on your iPhone or simulator.
4. If desired, add a UIKit-based PDF export helper next.
5. Archive and distribute through TestFlight when ready.

## Notes
- SwiftUI supports paged `TabView` using `PageTabViewStyle`. Apple documents this page-style tab view for swipeable paging interfaces.
- TestFlight is Apple's official beta distribution path for sharing app builds with testers for up to 90 days per build.
