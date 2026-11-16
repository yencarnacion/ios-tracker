import XCTest
@testable import HabitCore

final class ScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }
    private func date(_ key: String, hour: Int = 12) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Day.date(key, calendar: calendar)!)!
    }
    private func key(_ value: Date?) -> String? { value.map { Day.key($0, calendar: calendar) } }
    private func dates(_ schedule: TaskSchedule, from: String, start: String, count: Int) -> [String] {
        schedule.occurrences(onOrAfter: date(from), starting: date(start), count: count, calendar: calendar).map { Day.key($0, calendar: calendar) }
    }

    func testWeekdaysAndSaturdays() {
        let workdays = TaskSchedule.weekdays([2, 3, 4, 5, 6])
        XCTAssertEqual(dates(workdays, from: "2026-11-16", start: "2026-11-16", count: 7),
                       ["2026-11-16", "2026-11-17", "2026-11-18", "2026-11-19", "2026-11-20", "2026-11-23", "2026-11-24"])
        XCTAssertEqual(dates(.weekdays([7]), from: "2026-11-16", start: "2026-11-16", count: 3),
                       ["2026-11-21", "2026-11-28", "2026-12-05"])
    }

    func testFutureStartDoesNotScheduleEarlierDays() {
        let h = Habit(title: "Future weekdays", createdAt: date("2027-01-01"), schedule: .weekdays([2, 3, 4, 5, 6]))
        XCTAssertFalse(h.isScheduled(on: date("2026-12-31"), calendar: calendar))
        XCTAssertEqual(key(h.nextScheduledDate(onOrAfter: date("2026-11-16"), calendar: calendar)), "2027-01-01")
    }

    func testDayIntervalsAcrossSpringAndFallDST() {
        XCTAssertEqual(dates(.interval(days: 2), from: "2026-03-07", start: "2026-03-07", count: 4),
                       ["2026-03-07", "2026-03-09", "2026-03-11", "2026-03-13"])
        XCTAssertEqual(dates(.interval(days: 2), from: "2026-10-31", start: "2026-10-31", count: 4),
                       ["2026-10-31", "2026-11-02", "2026-11-04", "2026-11-06"])
    }

    func testMaximumIntervalAndFutureSearch() {
        XCTAssertEqual(TaskSchedule.maximumIntervalDays, 730)
        XCTAssertEqual(dates(.interval(days: 730), from: "2026-11-17", start: "2026-11-16", count: 2), ["2028-11-15", "2030-11-15"])
        XCTAssertFalse(TaskSchedule.interval(days: 731).isValid)
        XCTAssertFalse(TaskSchedule.interval(days: 0).isValid)
    }

    func testLateCompletionDoesNotMoveIntervalAnchor() {
        var h = Habit(title: "Every three days", createdAt: date("2026-11-16"), schedule: .interval(days: 3))
        h.record(HabitLog(occurredAt: date("2026-11-17")), calendar: calendar)
        XCTAssertEqual(key(h.nextScheduledDate(onOrAfter: date("2026-11-18"), calendar: calendar)), "2026-11-19")
        XCTAssertTrue(h.isScheduled(on: date("2026-11-17"), calendar: calendar), "Actual off-schedule check-ins remain visible in history.")
    }

    func testMonthly31UsesLastDayWithoutDrifting() {
        XCTAssertEqual(dates(.monthly(day: 31), from: "2027-01-31", start: "2027-01-01", count: 4),
                       ["2027-01-31", "2027-02-28", "2027-03-31", "2027-04-30"])
        XCTAssertEqual(dates(.monthly(day: 31), from: "2028-02-01", start: "2027-01-01", count: 2), ["2028-02-29", "2028-03-31"])
    }

    func testMonthlyDateBeforeAndAfterThisMonthsOccurrence() {
        let schedule = TaskSchedule.monthly(day: 15)
        XCTAssertEqual(dates(schedule, from: "2026-11-14", start: "2026-11-01", count: 2), ["2026-11-15", "2026-12-15"])
        XCTAssertEqual(dates(schedule, from: "2026-11-16", start: "2026-11-01", count: 2), ["2026-12-15", "2027-01-15"])
        XCTAssertFalse(schedule.isDue(on: date("2026-11-15"), starting: date("2026-11-16"), calendar: calendar))
    }

    func testAnnualSeptember12AndStartBoundary() {
        XCTAssertEqual(dates(.yearly(month: 9, day: 12), from: "2026-11-16", start: "2026-11-16", count: 3),
                       ["2027-09-12", "2028-09-12", "2029-09-12"])
        XCTAssertEqual(dates(.yearly(month: 9, day: 12), from: "2026-01-01", start: "2026-09-13", count: 1), ["2027-09-12"])
    }

    func testFebruary29OnlyOccursInLeapYearsIncludingCenturyGap() {
        XCTAssertEqual(dates(.yearly(month: 2, day: 29), from: "2026-11-16", start: "2026-11-16", count: 2), ["2028-02-29", "2032-02-29"])
        XCTAssertEqual(dates(.yearly(month: 2, day: 29), from: "2096-03-01", start: "2096-01-01", count: 1), ["2104-02-29"])
    }

    func testFutureOneTimeTaskOnlyOnItsSpecificDate() {
        let due = date("2028-11-16")
        let h = Habit(title: "Future appointment", createdAt: date("2026-11-16"), schedule: .once(due))
        XCTAssertTrue(h.isOneOff)
        XCTAssertEqual(h.scheduledOnceDate, due)
        XCTAssertFalse(h.isScheduled(on: date("2028-11-15"), calendar: calendar))
        XCTAssertTrue(h.isScheduled(on: due, calendar: calendar))
        XCTAssertFalse(h.isScheduled(on: date("2028-11-17"), calendar: calendar))
        XCTAssertEqual(key(h.nextScheduledDate(onOrAfter: date("2026-11-16"), calendar: calendar)), "2028-11-16")
        XCTAssertNil(h.nextScheduledDate(onOrAfter: date("2028-11-17"), calendar: calendar))
    }

    func testMonthlySummaryCountsOnlyDueDaysAndExcludesFuture() {
        var h = Habit(title: "Monthly", createdAt: date("2026-01-01"), schedule: .monthly(day: 31))
        h.record(HabitLog(occurredAt: date("2026-01-31")), calendar: calendar)
        let summary = HabitSummary(habits: [h], days: Day.range(from: date("2026-01-01"), through: date("2026-04-30"), calendar: calendar), today: date("2026-03-01"), calendar: calendar)
        XCTAssertEqual(summary.scheduled, 2)
        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.rate, 0.5)
    }

    func testArchivedTaskHasNoLaterOccurrencesOrReminders() {
        let h = Habit(title: "Archived", createdAt: date("2026-11-16"), archivedAt: date("2026-11-20"), reminderHour: 9, schedule: .interval(days: 7))
        XCTAssertNil(h.nextScheduledDate(onOrAfter: date("2026-11-21"), calendar: calendar))
        XCTAssertFalse(h.isScheduled(on: date("2026-11-23"), calendar: calendar))
        XCTAssertTrue(h.reminders(after: date("2026-11-16"), calendar: calendar).isEmpty)
    }

    func testWeeklyRemindersRepeatOnlyOnSelectedWeekdays() {
        let h = Habit(title: "Workdays", weekdays: [2, 3, 4, 5, 6], createdAt: date("2026-11-01"), reminderHour: 9)
        let plan = h.reminders(after: date("2026-11-16"), calendar: calendar)
        XCTAssertEqual(plan.count, 5)
        XCTAssertTrue(plan.allSatisfy(\.repeats))
        XCTAssertEqual(Set(plan.compactMap { $0.components.weekday }), [2, 3, 4, 5, 6])
    }

    func testFutureWeekdayReminderDoesNotFireBeforeStart() {
        let h = Habit(title: "Start Friday", createdAt: date("2026-11-20"), reminderHour: 9, schedule: .weekdays([2, 3, 4, 5, 6]))
        let plan = h.reminders(after: date("2026-11-16"), calendar: calendar)
        XCTAssertEqual(plan.count, 7)
        XCTAssertFalse(plan.contains(where: \.repeats))
        XCTAssertEqual(plan.first?.suffix, "2026-11-20")
    }

    func testMonthlyRemindersUseExactDatesForShortMonths() {
        let h = Habit(title: "End of month", createdAt: date("2027-01-01"), reminderHour: 9, schedule: .monthly(day: 31))
        let plan = h.reminders(after: date("2027-01-31", hour: 10), calendar: calendar)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.suffix, "2027-02-28")
        XCTAssertEqual(plan[1].suffix, "2027-03-31")
        XCTAssertTrue(plan.allSatisfy { !$0.repeats && $0.components.hour == 9 && $0.components.year != nil })
    }

    func testIntervalAndAnnualReminderDates() {
        let interval = Habit(title: "Long interval", createdAt: date("2026-11-16"), reminderHour: 9, schedule: .interval(days: 730))
        let plan = interval.reminders(after: date("2026-11-16", hour: 10), calendar: calendar)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.suffix, "2028-11-15")
        let yearly = Habit(title: "Annual", createdAt: date("2026-11-16"), reminderHour: 9, schedule: .yearly(month: 9, day: 12))
        XCTAssertEqual(yearly.reminders(after: date("2026-11-16"), calendar: calendar).first?.suffix, "2027-09-12")
    }

    func testOneTimeReminderIsNotRepeatedOrScheduledInThePast() {
        let h = Habit(title: "Appointment", createdAt: date("2026-11-16"), reminderHour: 9, schedule: .once(date("2027-09-12")))
        let plan = h.reminders(after: date("2026-11-16"), calendar: calendar)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].suffix, "2027-09-12")
        XCTAssertFalse(plan[0].repeats)
        XCTAssertTrue(h.reminders(after: date("2027-09-12", hour: 10), calendar: calendar).isEmpty)
    }

    func testVersion1BackupMigratesWithoutChangingLogsOrLegacySchedules() throws {
        var weekly = Habit(title: "Old weekdays", weekdays: [2, 3, 4, 5, 6], createdAt: date("2026-11-01"))
        weekly.record(HabitLog(occurredAt: date("2026-11-16"), amount: 2, note: "Keep this"), calendar: calendar)
        weekly.setNote("Keep daily note", on: date("2026-11-16"), calendar: calendar)
        let once = Habit(title: "Old one-off", createdAt: date("2026-11-10"), oneOffDate: date("2026-11-10"))
        var old = HabitDocument(habits: [weekly, once], moods: ["2026-11-16": "🙂"])
        old.version = 1
        var json = try JSONSerialization.jsonObject(with: old.encoded()) as! [String: Any]
        json["habits"] = (json["habits"] as! [[String: Any]]).map { habit in
            var h = habit; h.removeValue(forKey: "schedule"); return h
        }
        let migrated = try HabitDocument.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.habits, old.habits)
        XCTAssertEqual(migrated.moods, old.moods)
        XCTAssertEqual(migrated.habits[0].effectiveSchedule, .weekdays([2, 3, 4, 5, 6]))
        XCTAssertTrue(migrated.habits[1].isOneOff)
    }

    func testEveryScheduleSurvivesBackupRoundTrip() throws {
        let start = date("2026-11-16")
        let rules: [TaskSchedule] = [.weekdays([7]), .interval(days: 730), .monthly(day: 31), .yearly(month: 9, day: 12), .once(date("2028-11-16"))]
        let doc = HabitDocument(habits: rules.enumerated().map { Habit(title: "Task \($0.offset)", createdAt: start, schedule: $0.element) })
        XCTAssertEqual(try HabitDocument.decode(doc.encoded()), doc)
    }

    func testInvalidSchedulesCannotBeImported() throws {
        let invalid: [TaskSchedule] = [.weekdays([]), .weekdays([8]), .interval(days: 0), .interval(days: 731), .monthly(day: 0), .monthly(day: 32), .yearly(month: 2, day: 30), .yearly(month: 13, day: 1)]
        for rule in invalid {
            XCTAssertFalse(rule.isValid)
            XCTAssertThrowsError(try HabitDocument.decode(HabitDocument(habits: [Habit(title: "Invalid", schedule: rule)]).encoded()))
        }
    }

    func testChangingFutureStartKeepsExistingHistoryAndStreaks() {
        var h = Habit(title: "Keep history", createdAt: date("2026-11-16"), schedule: .weekdays(Set(1...7)))
        let log = HabitLog(occurredAt: date("2026-11-16"))
        h.record(log, calendar: calendar)
        h.createdAt = date("2027-01-01")
        h.schedule = .monthly(day: 1)
        XCTAssertTrue(h.isScheduled(on: date("2026-11-16"), calendar: calendar))
        XCTAssertEqual(h.allLogs, [log])
        XCTAssertEqual(h.bestStreak(through: date("2026-11-16"), calendar: calendar), 1)
    }

    func testNextOccurrenceAndDueChecksAgreeAcrossCalendarBoundaries() {
        let rules: [TaskSchedule] = [.weekdays([2, 3, 4, 5, 6]), .interval(days: 17), .monthly(day: 31), .yearly(month: 2, day: 29), .once(date("2028-01-01"))]
        let start = date("2026-11-16")
        for rule in rules {
            for offset in stride(from: 0, through: 800, by: 13) {
                let probe = Day.adding(offset, to: start, calendar: calendar)
                if let next = rule.nextOccurrence(onOrAfter: probe, starting: start, calendar: calendar) {
                    XCTAssertGreaterThanOrEqual(next, calendar.startOfDay(for: probe))
                    XCTAssertTrue(rule.isDue(on: next, starting: start, calendar: calendar))
                    if rule.isDue(on: probe, starting: start, calendar: calendar) { XCTAssertEqual(next, calendar.startOfDay(for: probe)) }
                }
            }
        }
    }
}
