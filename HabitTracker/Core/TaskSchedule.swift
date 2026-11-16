import Foundation

public enum ScheduleKind: String, CaseIterable, Identifiable, Sendable {
    case weekdays, interval, monthly, yearly, once
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .weekdays: "Selected weekdays"
        case .interval: "Every X days"
        case .monthly: "Every month"
        case .yearly: "Every year"
        case .once: "One time"
        }
    }
}

public enum TaskSchedule: Codable, Equatable, Sendable {
    public static let maximumIntervalDays = 730
    case weekdays(Set<Int>)
    case interval(days: Int)
    case monthly(day: Int)
    case yearly(month: Int, day: Int)
    case once(Date)

    public var kind: ScheduleKind {
        switch self {
        case .weekdays: .weekdays
        case .interval: .interval
        case .monthly: .monthly
        case .yearly: .yearly
        case .once: .once
        }
    }

    public var isValid: Bool {
        switch self {
        case .weekdays(let days): !days.isEmpty && days.isSubset(of: Set(1...7))
        case .interval(let days): (1...Self.maximumIntervalDays).contains(days)
        case .monthly(let day): (1...31).contains(day)
        case .yearly(let month, let day):
            Self.exactDate(year: 2000, month: month, day: day, calendar: Calendar(identifier: .gregorian)) != nil
        case .once(let date): date.timeIntervalSince1970.isFinite && date >= Date(timeIntervalSince1970: 0)
        }
    }

    public func isDue(on date: Date, starting start: Date, calendar: Calendar = .current) -> Bool {
        guard isValid else { return false }
        let day = calendar.startOfDay(for: date), first = calendar.startOfDay(for: start)
        if case .once(let scheduled) = self { return calendar.isDate(scheduled, inSameDayAs: day) }
        guard day >= first else { return false }
        switch self {
        case .weekdays(let days): return days.contains(calendar.component(.weekday, from: day))
        case .interval(let interval):
            let elapsed = calendar.dateComponents([.day], from: first, to: day).day ?? 0
            return elapsed % interval == 0
        case .monthly(let selected):
            guard let range = calendar.range(of: .day, in: .month, for: day) else { return false }
            return calendar.component(.day, from: day) == min(selected, range.count)
        case .yearly(let month, let selected):
            return calendar.component(.month, from: day) == month && calendar.component(.day, from: day) == selected
        case .once: return false
        }
    }

    /// Finds a scheduled day, including the search day. Calendar-day arithmetic survives DST.
    public func nextOccurrence(onOrAfter date: Date, starting start: Date, calendar: Calendar = .current) -> Date? {
        guard isValid else { return nil }
        let search = calendar.startOfDay(for: date)
        if case .once(let scheduled) = self {
            let day = calendar.startOfDay(for: scheduled)
            return day >= search ? day : nil
        }
        let first = calendar.startOfDay(for: start), candidate = max(search, first)
        switch self {
        case .weekdays(let days):
            return (0..<7).map { Day.adding($0, to: candidate, calendar: calendar) }
                .first { days.contains(calendar.component(.weekday, from: $0)) }
        case .interval(let interval):
            let elapsed = calendar.dateComponents([.day], from: first, to: candidate).day ?? 0
            return Day.adding((interval - elapsed % interval) % interval, to: candidate, calendar: calendar)
        case .monthly(let selected):
            guard let month = calendar.dateInterval(of: .month, for: candidate)?.start else { return nil }
            for offset in 0...1 {
                guard let base = calendar.date(byAdding: .month, value: offset, to: month),
                      let range = calendar.range(of: .day, in: .month, for: base) else { continue }
                let occurrence = Day.adding(min(selected, range.count) - 1, to: base, calendar: calendar)
                if occurrence >= candidate { return occurrence }
            }
            return nil
        case .yearly(let month, let selected):
            let year = calendar.component(.year, from: candidate)
            // Eight years also covers February 29 across a non-leap century such as 2100.
            for nextYear in year...(year + 8) {
                if let occurrence = Self.exactDate(year: nextYear, month: month, day: selected, calendar: calendar), occurrence >= candidate {
                    return occurrence
                }
            }
            return nil
        case .once: return nil
        }
    }

    public func occurrences(onOrAfter date: Date, starting start: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = [], cursor = calendar.startOfDay(for: date)
        for _ in 0..<max(0, min(count, 100)) {
            guard let next = nextOccurrence(onOrAfter: cursor, starting: start, calendar: calendar) else { break }
            dates.append(next)
            cursor = Day.adding(1, to: next, calendar: calendar)
        }
        return dates
    }

    public func summary(calendar: Calendar = .current) -> String {
        switch self {
        case .weekdays(let days):
            if days == Set(1...7) { return "Every day" }
            if days == [2, 3, 4, 5, 6] { return "Monday–Friday" }
            if days == [1, 7] { return "Every weekend" }
            if days.count == 1, let day = days.first, (1...7).contains(day) { return "Every \(calendar.weekdaySymbols[day - 1])" }
            return [2, 3, 4, 5, 6, 7, 1].filter { days.contains($0) }.map { calendar.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        case .interval(let days): return days == 1 ? "Every day" : "Every \(days) days"
        case .monthly(let day): return "Monthly · day \(day)"
        case .yearly(let month, let day):
            guard let date = Self.exactDate(year: 2000, month: month, day: day, calendar: calendar) else { return "Every year" }
            return "Yearly · \(date.formatted(.dateTime.month(.wide).day()))"
        case .once(let date): return "Once · \(date.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private static func exactDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else { return nil }
        return date
    }
}

public struct HabitReminder: Equatable, Sendable {
    public var suffix: String
    public var components: DateComponents
    public var repeats: Bool
}

extension Habit {
    /// Weekday schedules already underway repeat indefinitely. Date-based schedules queue seven exact occurrences.
    public func reminders(after now: Date, calendar: Calendar = .current) -> [HabitReminder] {
        guard archivedAt == nil, let hour = reminderHour, (0...23).contains(hour), (0...59).contains(reminderMinute) else { return [] }
        if case .weekdays(let weekdays) = effectiveSchedule,
           calendar.startOfDay(for: createdAt) <= calendar.startOfDay(for: now) {
            let days: [Int?] = weekdays.count == 7 ? [nil] : weekdays.sorted().map { Optional($0) }
            return days.map { day in
                var c = DateComponents()
                c.hour = hour; c.minute = reminderMinute; c.weekday = day
                return HabitReminder(suffix: "weekday-\(day ?? 0)", components: c, repeats: true)
            }
        }
        var result: [HabitReminder] = []
        // Include an eighth day candidate in case today's chosen reminder time has already passed.
        for day in effectiveSchedule.occurrences(onOrAfter: now, starting: createdAt, count: 8, calendar: calendar) {
            guard let date = calendar.date(bySettingHour: hour, minute: reminderMinute, second: 0, of: day), date > now else { continue }
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            result.append(HabitReminder(suffix: Day.key(day, calendar: calendar), components: components, repeats: false))
            if result.count == 7 { break }
        }
        return result
    }
}
