import Foundation

public struct MetricField: Identifiable, Codable, Equatable, Sendable {
    public static let maximumActive = 6
    public static let maximumTotal = 30
    public var id: UUID
    public var name: String
    public var unit: String
    public var archived: Bool
    public init(id: UUID = UUID(), name: String, unit: String = "", archived: Bool = false) {
        self.id = id; self.name = name; self.unit = unit; self.archived = archived
    }
    public var key: String { id.uuidString }
    public var label: String { unit.isEmpty ? name : "\(name) (\(unit))" }
}

public enum MeasurementTemplate: String, CaseIterable, Identifiable, Sendable {
    case weightKG = "Weight (kg)", weightLB = "Weight (lb)", rowing = "Rowing", custom = "Custom values"
    public var id: String { rawValue }
    public var fields: [MetricField] {
        switch self {
        case .weightKG: [MetricField(name: "Weight", unit: "kg")]
        case .weightLB: [MetricField(name: "Weight", unit: "lb")]
        case .rowing: [MetricField(name: "Duration", unit: "min"), MetricField(name: "Distance", unit: "m")]
        case .custom: [MetricField(name: "Value")]
        }
    }
}

public enum NumericValue {
    public static let maximumMagnitude = 1_000_000_000_000.0
    public static func isValid(_ value: Double) -> Bool { value.isFinite && abs(value) <= maximumMagnitude }

    /// Accept a locale's decimal separator without treating punctuation as digit grouping.
    public static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = separator == "." ? input : input.replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty,
              normalized.allSatisfy({ "0123456789.-+eE".contains($0) }),
              let value = Double(normalized), isValid(value) else { return nil }
        return value
    }

    public static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.significantDigits(1...12)).grouping(.never))
    }

    public static func editText(_ value: Double, locale: Locale = .current) -> String {
        String(value).replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}

public struct MeasurementPoint: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var value: Double
}

public struct MeasurementSeries: Equatable, Sendable {
    public let points: [MeasurementPoint]
    public init(points: [MeasurementPoint]) { self.points = points }
    public var first: MeasurementPoint? { points.first }
    public var latest: MeasurementPoint? { points.last }
    public var minimum: Double? { points.map(\.value).min() }
    public var maximum: Double? { points.map(\.value).max() }
    public var change: Double? {
        guard let first, let latest else { return nil }
        return latest.value - first.value
    }
    public var valueRange: ClosedRange<Double> {
        guard let low = minimum, let high = maximum else { return 0...1 }
        let padding = high == low ? max(abs(low) * 0.03, 0.5) : (high - low) * 0.1
        return (low - padding)...(high + padding)
    }
}

extension Habit {
    public var isNumeric: Bool { !(metricFields ?? []).isEmpty }
    public var activeMetrics: [MetricField] { (metricFields ?? []).filter { !$0.archived } }

    public func hasValues(for fieldID: UUID) -> Bool {
        allLogs.contains { $0.values?[fieldID.uuidString] != nil }
    }

    public func accepts(_ log: HabitLog) -> Bool {
        guard (1...9999).contains(log.amount), log.note.count <= 5000 else { return false }
        guard isNumeric else { return log.values?.isEmpty != false }
        guard log.amount == 1, let values = log.values, !values.isEmpty else { return false }
        let known = Set((metricFields ?? []).map(\.key))
        return Set(values.keys).isSubset(of: known) && values.values.allSatisfy(NumericValue.isValid)
    }

    public func valueSummary(for log: HabitLog) -> String {
        (metricFields ?? []).compactMap { field in
            guard let value = log.values?[field.key] else { return nil }
            return "\(field.name): \(NumericValue.text(value))\(field.unit.isEmpty ? "" : " \(field.unit)")"
        }.joined(separator: " · ")
    }

    public func series(for fieldID: UUID, from start: Date? = nil, through end: Date? = nil) -> MeasurementSeries {
        let points = allLogs.compactMap { log -> MeasurementPoint? in
            guard let value = log.values?[fieldID.uuidString], NumericValue.isValid(value),
                  start.map({ log.occurredAt >= $0 }) ?? true,
                  end.map({ log.occurredAt <= $0 }) ?? true else { return nil }
            return MeasurementPoint(id: log.id, date: log.occurredAt, value: value)
        }.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
        return MeasurementSeries(points: points)
    }
}

public enum ActivityCSV {
    public static func export(_ document: HabitDocument) -> String {
        var rows = [["Item", "Type", "Schedule", "Local date", "Local time", "Timestamp (UTC)", "Entry ID", "Amount", "Unit", "Metric", "Value", "Metric unit", "Note"]]
        let pairs = document.habits.flatMap { habit in habit.allLogs.map { (habit, $0) } }.sorted { $0.1.occurredAt < $1.1.occurredAt }
        for (habit, log) in pairs {
            let base = [habit.title, habit.isNumeric ? "Values" : habit.isOneOff ? "One-off" : "Recurring", habit.effectiveSchedule.summary(),
                        Day.key(log.occurredAt), log.occurredAt.formatted(date: .omitted, time: .standard), log.occurredAt.ISO8601Format(),
                        log.id.uuidString, String(log.amount), habit.unit]
            if habit.isNumeric {
                for field in habit.metricFields ?? [] {
                    if let value = log.values?[field.key] { rows.append(base + [field.name, String(value), field.unit, log.note]) }
                }
            } else { rows.append(base + ["", "", "", log.note]) }
        }
        return rows.map { row in row.enumerated().map { cell($0.element, numeric: $0.offset == 10 || $0.offset == 7) }.joined(separator: ",") }.joined(separator: "\r\n")
    }

    private static func cell(_ value: String, numeric: Bool) -> String {
        let safe = !numeric && ["=", "+", "-", "@", "\t", "\r"].contains(where: value.hasPrefix) ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
