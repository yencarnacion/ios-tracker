# ios-tracker — iOS habit & activity tracker

A native, offline iPhone app for repeating habits and the things you did just once. Inspired by soft pastel habit cards, a weekly day selector, circular counters, and a calendar report.

## What it does

- **Recurring tasks:** choose selected weekdays, every X days (1–730), every month, or an annual month/day. Set a future first due date, a goal, unit, emoji, color, and optional local reminder.
- **Numerical trackers:** choose **Values**, then a Weight (kg/lb), Rowing (duration in minutes and distance in meters), or custom template. Define up to six named values and units per tracker. Each entry records its timestamp, optional note, and one or more decimal values.
- **Charts:** view a separate interactive trend chart for each value over 7, 30, or 90 days, or all history. Tap/drag to inspect a recorded value and time; compare first-to-last change, lowest, highest, and entry count. Missing values stay missing rather than becoming zero.
- **Individual check-ins:** each action saves its own ID, exact timestamp, amount, and optional note. Log multiple times in a day, even after meeting the goal.
- **One-time tasks:** choose **One time** and a past, present, or future due date. Past or present one-offs can record their first timestamp immediately; future tasks wait until their due day and never repeat.
- **Timelines:** view a habit’s entries or open **Timeline** for activity across all items. Edit timestamps, amounts, or notes; delete individual entries after confirmation.
- **Upcoming:** see the next occurrence of every active task, open its details, or schedule another future task. The editor previews the next three due dates before saving.
- **History:** browse any day, add a one-off from the **All** menu or calendar, and backfill a check-in with its actual time.
- **Progress:** calendar rings, monthly goal completion, perfect days, habit streaks, and weekly/monthly/yearly reports.
- **Data:** local atomic storage, JSON backup/restore, CSV export with a row per measurement or ordinary check-in, and archive/restore. No account, ads, analytics, backend, or subscriptions.

## Record numbers

1. Tap **+**, choose **Values**, then **Use a template**.
2. Pick **Weight (kg)**, **Weight (lb)**, **Rowing**, or **Custom values**. Field names and units can be customized before recording.
3. Choose the same recurrence options as other tasks and save.
4. Open the tracker and tap **Record values**, or use the plus on its daily card. Set the actual date/time and enter any values you measured. For example, a rowing entry can contain **20.5 min** and **5000 m** at a single timestamp.
5. Inspect **Trends** in the tracker, or select it on the **Progress** tab. Choose a field and time range to see individual samples rather than daily averages.

Multiple entries in a day remain separate. Fields may be left blank when not measured, but every numeric entry requires at least one valid value. Zero and negative values are supported for appropriate custom measurements. The daily goal counts entries, not the magnitude of a measurement; recording a weight does not imply a weight target.

Units are locked once a field has recorded data. To use a new unit, add a new field; archived fields keep their old values and charts. Existing trackers with history retain their original check-in/value type so old completion counts cannot be reinterpreted as measurements. **Complete tasks** never invents values for numeric trackers.

CSV export uses one row per numeric field with its name, value, unit, entry ID, and exact timestamp. Multi-value entries share the same ID/time across their rows. JSON backups preserve the complete tracker definitions and entries.

## Schedule examples

| What you want | Choose |
| --- | --- |
| Monday through Friday | **Selected weekdays → Mon–Fri** |
| Every Saturday | **Selected weekdays → Saturdays** |
| Every 10 days, starting next month | **Every X days → 10**, then set **First due date** |
| Every month on the 15th | **Every month → Day of month → 15** |
| Every year on September 12 | **Every year → September → 12** |
| Just once on a future date | **One time**, then set **Due date** |

Intervals stay anchored to the first due date, even if a completion is late. A monthly task on the 29th, 30th, or 31st uses the last day of shorter months, then returns to the selected day the following month. An annual February 29 task runs only in leap years. The 730-day cap applies to day intervals; it does not restrict how far ahead you can choose a first due date or a one-time due date.

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

Core tests also verify decimal/localized input, zero and negative values, multi-value timestamps, partial entries, editing/deletion, field history, chart ranges, measurement CSV, and migration. Scheduling tests exercise each recurrence rule, short months, leap years, daylight saving transitions, next-occurrence lookup, reminder dates, version 1 migration, timestamp retention, streaks, reports, and backup validation. UI tests exercise logging, future one-time tasks, interval editing, weight charts and edits, rowing duration/distance and partial entries, persistence, timelines, and navigation.

## Data behavior

- The goal is a minimum: check-ins can exceed it without losing any timestamps.
- Quick completion logs the remaining amount as one check-in at the time you complete it. Use the clock button to enter separate amounts and times.
- One-offs with recorded entries keep their original day; their individual times remain editable.
- Reports count goals met, while check-in counts track the number of individual recorded actions. Future dates do not lower the completion rate.
- Streaks count scheduled days; an unfinished habit today has until the end of the day. Editing a habit’s schedule or goal recalculates past statistics.
- Dates display in the iPhone’s current time zone; backups preserve absolute timestamps and CSV includes both local time and UTC.
- Up to eight tasks can have local reminders. Weekday schedules already underway repeat indefinitely. Other schedules, including weekday schedules with a future start, queue their next seven exact reminder dates and replenish them whenever the app opens. Reminders may still fire after a goal is met.
- Existing version 1 and 2 habit data and backups migrate automatically, retaining IDs, timestamps, amounts, notes, and moods. New backups use format version 3 for numeric field definitions and values alongside all recurrence rules.
- Backups replace current data only after confirmation. A damaged local file is preserved rather than silently overwritten.
- Data lives in Application Support on the device. It is not automatically synchronized across devices. Export a backup before uninstalling the app.

## Structure

`HabitTracker/Core` is a small Foundation-only Swift package; the app uses SwiftUI and UserNotifications. `Tests/HabitCoreTests` contains model tests and `Tests/BloomUITests` contains simulator UI tests. `scripts/generate-icon.swift` generates the app icon from native vector shapes.

The supplied reference screenshots, build output, provisioning profiles, signing keys, and personal activity data are excluded from Git.
