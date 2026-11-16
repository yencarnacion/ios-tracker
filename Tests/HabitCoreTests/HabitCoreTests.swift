import XCTest
@testable import HabitCore

final class HabitCoreTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }
    private func date(_ key: String, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Day.date(key, calendar: calendar)!)!
    }

    func testCheckInsRetainEachTimestampAndCanExceedGoal() {
        let day = date("2026-11-16")
        var habit = Habit(title: "Water", target: 2, createdAt: day)
        let morning = HabitLog(occurredAt: date("2026-11-16", hour: 9, minute: 14), amount: 1)
        let lunch = HabitLog(occurredAt: date("2026-11-16", hour: 12, minute: 32), amount: 2)
        habit.record(morning, calendar: calendar); habit.record(lunch, calendar: calendar)
        let entry = habit.entry(on: day, calendar: calendar)
        XCTAssertEqual(entry.count, 3)
        XCTAssertEqual(entry.logs.map(\.occurredAt), [morning.occurredAt, lunch.occurredAt])
        XCTAssertEqual(habit.progress(on: day, calendar: calendar), 1)
    }

    func testEditingLogMovesItWithoutDuplicatingAndDeleteKeepsOthers() {
        let first = date("2026-11-16"), second = date("2026-11-17")
        var habit = Habit(title: "Read", createdAt: first)
        let keep = HabitLog(occurredAt: first)
        var moving = HabitLog(occurredAt: first, amount: 2)
        habit.record(keep, calendar: calendar); habit.record(moving, calendar: calendar)
        moving.occurredAt = second
        habit.record(moving, calendar: calendar)
        XCTAssertEqual(habit.entry(on: first, calendar: calendar).count, 1)
        XCTAssertEqual(habit.entry(on: second, calendar: calendar).count, 2)
        XCTAssertEqual(habit.allLogs.count, 2)
        habit.removeLog(moving.id)
        XCTAssertEqual(habit.allLogs, [keep])
    }

    func testOneOffNeverRepeats() {
        let monday = date("2026-11-16"), tuesday = date("2026-11-17")
        var item = Habit(title: "Car service", createdAt: monday, oneOffDate: monday)
        item.record(HabitLog(occurredAt: monday), calendar: calendar)
        XCTAssertTrue(item.isScheduled(on: monday, calendar: calendar))
        XCTAssertFalse(item.isScheduled(on: tuesday, calendar: calendar))
        XCTAssertFalse(item.isScheduled(on: Day.adding(7, to: monday, calendar: calendar), calendar: calendar))
        XCTAssertEqual(HabitSummary(habits: [item], days: [monday, tuesday], today: tuesday, calendar: calendar).scheduled, 1)
    }

    func testSchedulesStreaksAndTodayGracePeriod() {
        let monday = date("2026-11-09"), wednesday = date("2026-11-11"), friday = date("2026-11-13")
        var habit = Habit(title: "Run", weekdays: [2, 4, 6], createdAt: monday)
        habit.record(HabitLog(occurredAt: monday), calendar: calendar)
        habit.record(HabitLog(occurredAt: wednesday), calendar: calendar)
        XCTAssertFalse(habit.isScheduled(on: date("2026-11-10"), calendar: calendar))
        XCTAssertEqual(habit.currentStreak(through: friday, calendar: calendar), 2)
        XCTAssertEqual(habit.currentStreak(through: date("2026-11-14"), calendar: calendar), 0)
        XCTAssertEqual(habit.bestStreak(through: friday, calendar: calendar), 2)
    }

    func testMonthAndWeekAcrossDSTAndYearBoundary() {
        let week = Day.week(containing: date("2026-11-01"), calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(Day.key(week[0], calendar: calendar), "2026-10-26")
        XCTAssertEqual(Day.range(from: date("2026-10-31"), through: date("2026-11-02"), calendar: calendar).count, 3)
        let grid = Day.monthGrid(containing: date("2027-01-15"), calendar: calendar)
        XCTAssertEqual(grid.count, 42)
        XCTAssertEqual(Day.key(grid[0], calendar: calendar), "2026-12-28")
        XCTAssertNil(Day.date("2026-02-31", calendar: calendar))
    }

    func testSummaryExcludesFutureAndHandlesEmptyDays() {
        let today = date("2026-11-16")
        var habit = Habit(title: "Read", target: 2, createdAt: today)
        habit.record(HabitLog(occurredAt: today, amount: 2), calendar: calendar)
        let summary = HabitSummary(habits: [habit], days: [today, Day.adding(1, to: today, calendar: calendar)], today: today, calendar: calendar)
        XCTAssertEqual(summary.scheduled, 1); XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.perfectDays, 1); XCTAssertEqual(summary.rate, 1)
        XCTAssertEqual(HabitSummary(habits: [], days: [today], today: today).rate, 0)
    }

    func testBackupRoundTripKeepsTimestampsNotesAndOneOffs() throws {
        let day = date("2026-11-16")
        var item = Habit(title: "Appointment", createdAt: day, oneOffDate: day)
        item.record(HabitLog(occurredAt: day, amount: 1, note: "Arrived early"), calendar: calendar)
        item.setNote("A good day", on: day, calendar: calendar)
        let doc = HabitDocument(habits: [item], moods: ["2026-11-16": "🙂"])
        XCTAssertEqual(try HabitDocument.decode(doc.encoded()), doc)
    }

    func testInvalidBackupRejected() throws {
        var doc = HabitDocument(habits: [Habit(title: "", target: 0)])
        XCTAssertThrowsError(try HabitDocument.decode(doc.encoded()))
        doc = HabitDocument(); doc.version = 999
        XCTAssertThrowsError(try HabitDocument.decode(doc.encoded()))
        let h = Habit(title: "Read")
        XCTAssertThrowsError(try HabitDocument.decode(HabitDocument(habits: [h, h]).encoded()))
    }
}
