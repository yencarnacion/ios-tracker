# ios-tracker — iOS habit & activity tracker

A native, offline iPhone app for repeating habits and the things you did just once. Inspired by soft pastel habit cards, a weekly day selector, circular counters, and a calendar report.

## What it does

- **Repeating habits:** choose weekdays, daily goal, unit, emoji, color, and an optional local reminder.
- **Individual check-ins:** each action saves its own ID, exact timestamp, amount, and optional note. Log multiple times in a day, even after meeting the goal.
- **One-off items:** choose **Just this day** when adding an item. Record the first check-in immediately, including its time. The item stays in that day’s history and never repeats tomorrow.
- **Timelines:** view a habit’s entries or open **Timeline** for activity across all items. Edit timestamps, amounts, or notes; delete individual entries after confirmation.
- **History:** browse any day, add a one-off to a past day from the **All** menu, and backfill a check-in with its actual time.
- **Progress:** calendar rings, monthly goal completion, perfect days, habit streaks, and weekly/monthly/yearly reports.
- **Data:** local atomic storage, JSON backup/restore, CSV export with a row per check-in, and archive/restore. No account, ads, analytics, backend, or subscriptions.

## Run

Requires Xcode 16 or newer (built and tested with Xcode 26.2), iOS 17+, and optionally [XcodeGen](https://github.com/yonaskolb/XcodeGen) to regenerate the project.

1. Open `Bloom.xcodeproj`.
2. Select the **Bloom** scheme and a simulator or connected iPhone.
3. For a physical iPhone, select your Apple development team in **Signing & Capabilities** and choose a unique bundle identifier if needed.
4. Run. If prompted on the iPhone, enable Developer Mode and trust the developer.

The checked-in Xcode project is ready to open. To regenerate after changing `project.yml`:

```sh
xcodegen generate
```

## Verify

```sh
swift test
xcodebuild -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build/DerivedData test CODE_SIGNING_ALLOWED=NO
```

Core tests exercise independent timestamps, editing/moving/deleting entries, non-repeating items, recurrence, streaks, daylight saving transitions, month grids, future-day exclusion, and backup validation. UI tests exercise the complete logging and one-off creation flows, timelines, and navigation.

## Data behavior

- The goal is a minimum: check-ins can exceed it without losing any timestamps.
- Quick completion logs the remaining amount as one check-in at the time you complete it. Use the clock button to enter separate amounts and times.
- One-offs with recorded entries keep their original day; their individual times remain editable.
- Reports count goals met, while check-in counts track the number of individual recorded actions. Future dates do not lower the completion rate.
- Streaks count scheduled days; an unfinished habit today has until the end of the day. Editing a habit’s schedule or goal recalculates past statistics.
- Dates display in the iPhone’s current time zone; backups preserve absolute timestamps and CSV includes both local time and UTC.
- Reminders repeat on the chosen weekdays until disabled or archived. Up to eight repeating habits can have reminders. They are time-based and may still fire after a goal is met.
- Backups replace current data only after confirmation. A damaged local file is preserved rather than silently overwritten.
- Data lives in Application Support on the device. It is not automatically synchronized across devices. Export a backup before uninstalling the app.

## Structure

`HabitTracker/Core` is a small Foundation-only Swift package; the app uses SwiftUI and UserNotifications. `Tests/HabitCoreTests` contains model tests and `Tests/BloomUITests` contains simulator UI tests. `scripts/generate-icon.swift` generates the app icon from native vector shapes.

The supplied reference screenshots, build output, provisioning profiles, signing keys, and personal activity data are excluded from Git.
