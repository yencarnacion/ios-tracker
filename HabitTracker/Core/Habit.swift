import Foundation

public enum HabitTint: String, Codable, CaseIterable, Sendable {
    case mint, rose, lavender, sky, peach, lemon
}

public struct HabitLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var occurredAt: Date
    public var amount: Int
    public var note: String
    public var values: [String: Double]?
    public init(id: UUID = UUID(), occurredAt: Date = Date(), amount: Int = 1, note: String = "", values: [String: Double]? = nil) {
        self.id = id; self.occurredAt = occurredAt; self.amount = amount; self.note = note
        self.values = values
    }
}

public struct HabitEntry: Codable, Equatable, Sendable {
    public var logs: [HabitLog]
    public var note: String
    public var count: Int { logs.reduce(0) { $0 + $1.amount } }
    public init(logs: [HabitLog] = [], note: String = "") {
        self.logs = logs; self.note = note
    }
}

public struct Habit: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var emoji: String
    public var tint: HabitTint
    public var target: Int
    public var unit: String
    /// Calendar weekday numbers: Sunday = 1, Monday = 2.
    public var weekdays: Set<Int>
    public var oneOffDate: Date?
    /// Missing in version 1 backups; those retain their weekday or one-off schedule.
    public var schedule: TaskSchedule?
    public var metricFields: [MetricField]?
    public var createdAt: Date
    public var archivedAt: Date?
    public var reminderHour: Int?
    public var reminderMinute: Int
    public var entries: [String: HabitEntry]

    public init(id: UUID = UUID(), title: String, emoji: String = "🌟", tint: HabitTint = .mint,
                target: Int = 1, unit: String = "", weekdays: Set<Int> = Set(1...7),
                createdAt: Date = Date(), oneOffDate: Date? = nil, archivedAt: Date? = nil, reminderHour: Int? = nil,
                reminderMinute: Int = 0, entries: [String: HabitEntry] = [:], schedule: TaskSchedule? = nil, metricFields: [MetricField]? = nil) {
        self.id = id; self.title = title; self.emoji = emoji; self.tint = tint
        self.target = target; self.unit = unit; self.weekdays = weekdays
        self.createdAt = createdAt; self.oneOffDate = oneOffDate; self.archivedAt = archivedAt
        self.reminderHour = reminderHour; self.reminderMinute = reminderMinute
        self.entries = entries
        self.schedule = schedule
        self.metricFields = metricFields
    }

    public var effectiveSchedule: TaskSchedule { schedule ?? oneOffDate.map(TaskSchedule.once) ?? .weekdays(weekdays) }
    public var isOneOff: Bool { effectiveSchedule.kind == .once }
    public var scheduledOnceDate: Date? {
        if case .once(let date) = effectiveSchedule { return date }
        return nil
    }

    public func nextScheduledDate(onOrAfter date: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let next = effectiveSchedule.nextOccurrence(onOrAfter: date, starting: createdAt, calendar: calendar) else { return nil }
        if let archivedAt, next > calendar.startOfDay(for: archivedAt) { return nil }
        return next
    }

    public func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        if !entry(on: date, calendar: calendar).logs.isEmpty { return true }
        if let archivedAt, day > calendar.startOfDay(for: archivedAt) { return false }
        return effectiveSchedule.isDue(on: day, starting: createdAt, calendar: calendar)
    }

    public func entry(on date: Date, calendar: Calendar = .current) -> HabitEntry {
        entries[Day.key(date, calendar: calendar)] ?? HabitEntry()
    }

    public func progress(on date: Date, calendar: Calendar = .current) -> Double {
        min(1, Double(entry(on: date, calendar: calendar).count) / Double(max(1, target)))
    }

    public func isComplete(on date: Date, calendar: Calendar = .current) -> Bool {
        entry(on: date, calendar: calendar).count >= target
    }

    public mutating func setCount(_ count: Int, on date: Date, calendar: Calendar = .current) {
        guard !isNumeric else { return }
        let key = Day.key(date, calendar: calendar)
        var value = entries[key] ?? HabitEntry()
        let desired = max(0, count)
        if desired > value.count {
            let timestamp = Day.time(on: date, from: Date(), calendar: calendar)
            value.logs.append(HabitLog(occurredAt: timestamp, amount: min(9999, desired - value.count)))
        } else {
            var remove = value.count - desired
            while remove > 0, var last = value.logs.popLast() {
                if last.amount > remove { last.amount -= remove; value.logs.append(last); remove = 0 }
                else { remove -= last.amount }
            }
        }
        entries[key] = value
    }

    public mutating func record(_ log: HabitLog, calendar: Calendar = .current) {
        removeLog(log.id)
        let key = Day.key(log.occurredAt, calendar: calendar)
        var value = entries[key] ?? HabitEntry()
        value.logs.append(log)
        value.logs.sort { $0.occurredAt < $1.occurredAt }
        entries[key] = value
    }

    public mutating func removeLog(_ id: UUID) {
        for key in Array(entries.keys) { entries[key]?.logs.removeAll { $0.id == id } }
    }

    public var allLogs: [HabitLog] { entries.values.flatMap(\.logs).sorted { $0.occurredAt > $1.occurredAt } }

    public mutating func setNote(_ note: String, on date: Date, calendar: Calendar = .current) {
        let key = Day.key(date, calendar: calendar)
        var value = entries[key] ?? HabitEntry()
        value.note = note
        entries[key] = value
    }

    public func bestStreak(through today: Date = Date(), calendar: Calendar = .current) -> Int {
        var best = 0, streak = 0
        for day in Day.range(from: historyStart(calendar: calendar), through: today, calendar: calendar) where isScheduled(on: day, calendar: calendar) {
            streak = isComplete(on: day, calendar: calendar) ? streak + 1 : 0
            best = max(best, streak)
        }
        return best
    }

    public func currentStreak(through today: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        for day in Day.range(from: historyStart(calendar: calendar), through: today, calendar: calendar).reversed() where isScheduled(on: day, calendar: calendar) {
            // A habit due today still has time to be completed.
            if calendar.isDate(day, inSameDayAs: today) && !isComplete(on: day, calendar: calendar) { continue }
            guard isComplete(on: day, calendar: calendar) else { break }
            streak += 1
        }
        return streak
    }

    private func historyStart(calendar: Calendar) -> Date {
        entries.filter { !$0.value.logs.isEmpty }.keys.compactMap { Day.date($0, calendar: calendar) }.min().map { min($0, createdAt) } ?? createdAt
    }
}

public enum Day {
    public static func time(on day: Date, from time: Date, calendar: Calendar = .current) -> Date {
        let c = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(bySettingHour: c.hour ?? 12, minute: c.minute ?? 0, second: c.second ?? 0, of: day) ?? day
    }
    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              self.key(date, calendar: calendar) == key else { return nil }
        return date
    }

    public static func adding(_ days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    public static func range(from start: Date, through end: Date, calendar: Calendar = .current) -> [Date] {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        guard first <= last else { return [] }
        var values: [Date] = [], day = first
        while day <= last {
            values.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return values
    }

    public static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let weekday = calendar.component(.weekday, from: date)
        let monday = adding(-((weekday + 5) % 7), to: calendar.startOfDay(for: date), calendar: calendar)
        return (0..<7).map { adding($0, to: monday, calendar: calendar) }
    }

    public static func monthGrid(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let first = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        let start = week(containing: first, calendar: calendar)[0]
        return (0..<42).map { adding($0, to: start, calendar: calendar) }
    }
}

public struct HabitSummary: Equatable, Sendable {
    public var scheduled: Int = 0
    public var completed: Int = 0
    public var perfectDays: Int = 0
    public var rate: Double { scheduled == 0 ? 0 : Double(completed) / Double(scheduled) }

    public init(habits: [Habit], days: [Date], today: Date = Date(), calendar: Calendar = .current) {
        for day in days where calendar.startOfDay(for: day) <= calendar.startOfDay(for: today) {
            let due = habits.filter { $0.isScheduled(on: day, calendar: calendar) }
            let done = due.filter { $0.isComplete(on: day, calendar: calendar) }.count
            scheduled += due.count
            completed += done
            if !due.isEmpty && done == due.count { perfectDays += 1 }
        }
    }
}

public struct HabitDocument: Codable, Equatable, Sendable {
    public var version: Int = 3
    public var habits: [Habit]
    public var moods: [String: String]
    public init(habits: [Habit] = [], moods: [String: String] = [:]) {
        self.habits = habits; self.moods = moods
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> HabitDocument {
        guard data.count <= 10_000_000 else { throw DocumentError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var doc = try decoder.decode(Self.self, from: data)
        guard (1...3).contains(doc.version) else { throw DocumentError.version }
        guard doc.habits.count <= 500, Set(doc.habits.map(\.id)).count == doc.habits.count else { throw DocumentError.invalid }
        for h in doc.habits {
            guard !h.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  h.title.count <= 80, !h.emoji.isEmpty, h.emoji.count <= 4, h.unit.count <= 20,
                  (1...9999).contains(h.target), !h.weekdays.isEmpty, h.weekdays.isSubset(of: Set(1...7)),
                  h.reminderHour.map({ (0...23).contains($0) }) ?? true,
                  (0...59).contains(h.reminderMinute),
                  h.effectiveSchedule.isValid,
                  h.createdAt >= Date(timeIntervalSince1970: 0) else { throw DocumentError.invalid }
            if let fields = h.metricFields {
                guard !fields.isEmpty, fields.count <= MetricField.maximumTotal,
                      !h.activeMetrics.isEmpty, h.activeMetrics.count <= MetricField.maximumActive,
                      Set(fields.map(\.id)).count == fields.count,
                      Set(h.activeMetrics.map { $0.name.lowercased() }).count == h.activeMetrics.count else { throw DocumentError.invalid }
                for field in fields {
                    guard !field.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          field.name.count <= 40, field.unit.count <= 20 else { throw DocumentError.invalid }
                }
            }
            var logIDs = Set<UUID>()
            for (key, entry) in h.entries {
                guard Day.date(key) != nil, entry.logs.count <= 1000, entry.note.count <= 5000 else { throw DocumentError.invalid }
                for log in entry.logs {
                    guard h.accepts(log),
                          log.occurredAt >= Date(timeIntervalSince1970: 0),
                          logIDs.insert(log.id).inserted else { throw DocumentError.invalid }
                }
            }
        }
        for (key, mood) in doc.moods {
            guard Day.date(key) != nil, mood.count <= 4 else { throw DocumentError.invalid }
        }
        doc.version = 3
        return doc
    }

    public static func starter(today: Date = Date()) -> HabitDocument {
        HabitDocument(habits: [
            Habit(title: "Drink water", emoji: "💧", tint: .mint, target: 8, unit: "glasses", createdAt: today),
            Habit(title: "Read a little", emoji: "📖", tint: .lavender, target: 10, unit: "min", createdAt: today),
            Habit(title: "Move your body", emoji: "🏃", tint: .rose, target: 20, unit: "min", createdAt: today),
            Habit(title: "A mindful moment", emoji: "🌱", tint: .mint, target: 1, createdAt: today),
            Habit(title: "Get outside", emoji: "☀️", tint: .lemon, target: 1, createdAt: today)
        ])
    }
}

public enum DocumentError: LocalizedError {
    case version, invalid, tooLarge
    public var errorDescription: String? {
        switch self {
        case .version: "This backup uses an unsupported version."
        case .invalid: "This backup contains invalid habit data."
        case .tooLarge: "Choose a backup smaller than 10 MB."
        }
    }
}
