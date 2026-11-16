import XCTest
@testable import HabitCore

final class MeasurementTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_794_830_400)
    private var weight: MetricField { MetricField(name: "Weight", unit: "kg") }

    func testWeightValueKeepsDecimalTimeAndIndependentEntries() {
        let field = weight
        var h = Habit(title: "Weight", createdAt: day, metricFields: [field])
        let morning = HabitLog(occurredAt: day, values: [field.key: 82.45])
        let evening = HabitLog(occurredAt: day.addingTimeInterval(3600), values: [field.key: 82.1])
        h.record(morning); h.record(evening)
        XCTAssertEqual(h.allLogs.count, 2)
        XCTAssertEqual(h.allLogs.first?.occurredAt, evening.occurredAt)
        XCTAssertEqual(h.series(for: field.id).points.map(\.value), [82.45, 82.1])
        XCTAssertTrue(h.isComplete(on: day))
    }

    func testRowingDurationAndDistanceShareOneTimestampAndEntryID() {
        let fields = MeasurementTemplate.rowing.fields
        var h = Habit(title: "Rowing", createdAt: day, metricFields: fields)
        let log = HabitLog(occurredAt: day, note: "Steady pace", values: [fields[0].key: 20.5, fields[1].key: 5000])
        XCTAssertTrue(h.accepts(log))
        h.record(log)
        XCTAssertEqual(h.series(for: fields[0].id).first?.id, log.id)
        XCTAssertEqual(h.series(for: fields[1].id).first?.id, log.id)
        XCTAssertEqual(h.series(for: fields[0].id).first?.date, h.series(for: fields[1].id).first?.date)
        XCTAssertEqual(h.entry(on: day).count, 1)
        XCTAssertTrue(h.valueSummary(for: log).contains("20.5"))
        XCTAssertTrue(h.valueSummary(for: log).contains("5000"))
    }

    func testPartialMeasurementsAreNotReplacedWithZeros() {
        let fields = MeasurementTemplate.rowing.fields
        var h = Habit(title: "Rowing", createdAt: day, metricFields: fields)
        let log = HabitLog(occurredAt: day, values: [fields[0].key: 12])
        XCTAssertTrue(h.accepts(log)); h.record(log)
        XCTAssertEqual(h.series(for: fields[0].id).points.count, 1)
        XCTAssertTrue(h.series(for: fields[1].id).points.isEmpty)
        XCTAssertFalse(h.valueSummary(for: log).contains("Distance"))
    }

    func testZeroAndNegativeValuesAreRealMeasurements() {
        let field = MetricField(name: "Temperature", unit: "°C")
        var h = Habit(title: "Temperature", createdAt: day, metricFields: [field])
        let zero = HabitLog(occurredAt: day, values: [field.key: 0])
        let below = HabitLog(occurredAt: day.addingTimeInterval(60), values: [field.key: -4.25])
        XCTAssertTrue(h.accepts(zero)); XCTAssertTrue(h.accepts(below))
        h.record(zero); h.record(below)
        XCTAssertEqual(h.series(for: field.id).points.map(\.value), [0, -4.25])
    }

    func testNumericTrackerCannotBeCompletedWithoutValues() {
        let field = weight
        var h = Habit(title: "Weight", createdAt: day, metricFields: [field])
        XCTAssertFalse(h.accepts(HabitLog(occurredAt: day)))
        XCTAssertFalse(h.accepts(HabitLog(occurredAt: day, values: [:])))
        h.setCount(1, on: day)
        XCTAssertTrue(h.allLogs.isEmpty)
        XCTAssertFalse(h.isComplete(on: day))
        XCTAssertFalse(h.accepts(HabitLog(occurredAt: day, amount: 2, values: [field.key: 82])))
    }

    func testInvalidOrUnknownNumericValuesAreRejected() {
        let field = weight
        let h = Habit(title: "Weight", metricFields: [field])
        for value in [Double.nan, .infinity, -.infinity, NumericValue.maximumMagnitude + 1] {
            XCTAssertFalse(h.accepts(HabitLog(values: [field.key: value])))
        }
        XCTAssertFalse(h.accepts(HabitLog(values: [UUID().uuidString: 80])))
        XCTAssertFalse(Habit(title: "Normal task").accepts(HabitLog(values: [field.key: 80])))
    }

    func testEditingAndMovingNumericEntryPreservesIDAndValues() {
        let field = weight
        var h = Habit(title: "Weight", createdAt: day, metricFields: [field])
        var log = HabitLog(occurredAt: day, values: [field.key: 82])
        h.record(log)
        log.occurredAt = Day.adding(1, to: day)
        log.values = [field.key: 81.75]
        h.record(log)
        XCTAssertTrue(h.entry(on: day).logs.isEmpty)
        XCTAssertEqual(h.allLogs.count, 1)
        XCTAssertEqual(h.series(for: field.id).latest?.id, log.id)
        XCTAssertEqual(h.series(for: field.id).latest?.value, 81.75)
        h.removeLog(log.id)
        XCTAssertTrue(h.series(for: field.id).points.isEmpty)
    }

    func testSeriesSortsByTimestampAndFiltersInclusiveRange() {
        let field = weight
        var h = Habit(title: "Weight", createdAt: day, metricFields: [field])
        for (offset, value) in [(120.0, 82.0), (0.0, 83.0), (60.0, 82.5)] {
            h.record(HabitLog(occurredAt: day.addingTimeInterval(offset), values: [field.key: value]))
        }
        let series = h.series(for: field.id, from: day.addingTimeInterval(60), through: day.addingTimeInterval(120))
        XCTAssertEqual(series.points.map(\.value), [82.5, 82])
        XCTAssertEqual(series.change, -0.5)
        XCTAssertEqual(series.minimum, 82)
        XCTAssertEqual(series.maximum, 82.5)
    }

    func testChartRangesHandleSingleFlatZeroNegativeAndExtremeSeries() {
        let field = weight
        for values in [[0.0], [82.0, 82.0], [-5.0, -3.0], [-NumericValue.maximumMagnitude, NumericValue.maximumMagnitude]] {
            var h = Habit(title: "Values", createdAt: day, metricFields: [field])
            for (index, value) in values.enumerated() { h.record(HabitLog(occurredAt: day.addingTimeInterval(Double(index)), values: [field.key: value])) }
            let range = h.series(for: field.id).valueRange
            XCTAssertTrue(range.lowerBound.isFinite && range.upperBound.isFinite)
            XCTAssertLessThan(range.lowerBound, range.upperBound)
            XCTAssertTrue(values.allSatisfy { range.contains($0) })
        }
        XCTAssertEqual(MeasurementSeries(points: []).valueRange, 0...1)
    }

    func testArchivingFieldPreservesItsHistoryAndUnit() throws {
        var fields = MeasurementTemplate.rowing.fields
        var h = Habit(title: "Rowing", createdAt: day, metricFields: fields)
        let log = HabitLog(occurredAt: day, values: [fields[0].key: 20, fields[1].key: 5000])
        h.record(log)
        fields[1].archived = true
        h.metricFields = fields
        XCTAssertEqual(h.activeMetrics.count, 1)
        XCTAssertEqual(h.series(for: fields[1].id).latest?.value, 5000)
        XCTAssertTrue(h.hasValues(for: fields[1].id))
        let restored = try HabitDocument.decode(HabitDocument(habits: [h]).encoded())
        XCTAssertEqual(restored.habits[0].metricFields?[1].unit, "m")
        XCTAssertEqual(restored.habits[0].allLogs, [log])
    }

    func testLocalizedDecimalParsingAndExactEditRoundTrip() {
        XCTAssertEqual(NumericValue.parse("82.45", locale: Locale(identifier: "en_US")), 82.45)
        XCTAssertEqual(NumericValue.parse("82,45", locale: Locale(identifier: "de_DE")), 82.45)
        XCTAssertNil(NumericValue.parse("1,234", locale: Locale(identifier: "en_US")))
        for text in ["", "NaN", "Infinity", "2.3.4", "--3", "1/2", "1e99"] { XCTAssertNil(NumericValue.parse(text, locale: Locale(identifier: "en_US"))) }
        for value in [0, -2.75, 82.1234567890123, 0.0000000001, NumericValue.maximumMagnitude] {
            let locale = Locale(identifier: "de_DE")
            XCTAssertEqual(NumericValue.parse(NumericValue.editText(value, locale: locale), locale: locale), value)
        }
    }

    func testVersion1And2BackupsMigrateWithoutReinterpretingCounts() throws {
        var h = Habit(title: "Original", createdAt: day, schedule: .interval(days: 7))
        h.record(HabitLog(occurredAt: day, amount: 3, note: "Keep note"))
        for version in [1, 2] {
            var old = HabitDocument(habits: [h], moods: [Day.key(day): "🙂"]); old.version = version
            var json = try JSONSerialization.jsonObject(with: old.encoded()) as! [String: Any]
            json["habits"] = (json["habits"] as! [[String: Any]]).map { original in
                var item = original; item.removeValue(forKey: "metricFields"); return item
            }
            let migrated = try HabitDocument.decode(JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(migrated.version, 3)
            XCTAssertFalse(migrated.habits[0].isNumeric)
            XCTAssertEqual(migrated.habits, old.habits)
            XCTAssertEqual(migrated.moods, old.moods)
        }
    }

    func testBackupRoundTripPreservesMultipleMetricValuesAndSchedules() throws {
        let fields = MeasurementTemplate.rowing.fields
        var h = Habit(title: "Rowing", createdAt: day, schedule: .weekdays([2, 3, 4, 5, 6]), metricFields: fields)
        h.record(HabitLog(occurredAt: day, note: "Session", values: [fields[0].key: 20.5, fields[1].key: 5000]))
        let doc = HabitDocument(habits: [h])
        XCTAssertEqual(try HabitDocument.decode(doc.encoded()), doc)
    }

    func testMalformedFieldDefinitionsAndValueReferencesCannotBeImported() throws {
        let field = weight
        let badFields = [[MetricField(name: "")], [field, field], [MetricField(name: "Same"), MetricField(name: "same")], [MetricField(name: "Old", archived: true)], (0..<7).map { MetricField(name: "Field \($0)") }]
        for fields in badFields { XCTAssertThrowsError(try HabitDocument.decode(HabitDocument(habits: [Habit(title: "Invalid", metricFields: fields)]).encoded())) }
        var h = Habit(title: "Bad reference", createdAt: day, metricFields: [field])
        h.record(HabitLog(occurredAt: day, values: [UUID().uuidString: 80]))
        XCTAssertThrowsError(try HabitDocument.decode(HabitDocument(habits: [h]).encoded()))
    }

    func testCSVContainsOneNumericRowPerFieldWithSharedTimestamp() {
        let fields = MeasurementTemplate.rowing.fields
        var h = Habit(title: "Rowing", createdAt: day, metricFields: fields)
        let log = HabitLog(occurredAt: day, note: "Test, with commas", values: [fields[0].key: 20.5, fields[1].key: 5000])
        h.record(log)
        let csv = ActivityCSV.export(HabitDocument(habits: [h]))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 3)
        XCTAssertTrue(csv.contains("\"Duration\",\"20.5\",\"min\""))
        XCTAssertTrue(csv.contains("\"Distance\",\"5000.0\",\"m\""))
        XCTAssertEqual(csv.components(separatedBy: log.id.uuidString).count - 1, 2)
        XCTAssertEqual(csv.components(separatedBy: log.occurredAt.ISO8601Format()).count - 1, 2)
    }

    func testCSVProtectsTextButLeavesNegativeMeasurementsNumeric() {
        let field = MetricField(name: "Temperature", unit: "°C")
        var h = Habit(title: "=unsafe()", createdAt: day, metricFields: [field])
        h.record(HabitLog(occurredAt: day, note: "@unsafe", values: [field.key: -5]))
        let csv = ActivityCSV.export(HabitDocument(habits: [h]))
        XCTAssertTrue(csv.contains("\"'=unsafe()\""))
        XCTAssertTrue(csv.contains("\"'@unsafe\""))
        XCTAssertTrue(csv.contains("\"-5.0\""))
        XCTAssertFalse(csv.contains("\"'-5.0\""))
    }
}
