import SwiftUI
import Charts
import HabitCore

private enum TrendRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "90D", all = "All"
    var id: String { rawValue }
    var days: Int? {
        switch self { case .week: 7; case .month: 30; case .quarter: 90; case .all: nil }
    }
}

struct MetricChartView: View {
    @Environment(HabitStore.self) private var store
    let habitID: UUID
    @State private var selectedField: UUID?
    @State private var range: TrendRange = .month
    @State private var selectedTime: Date?
    private var habit: Habit? { store.habit(habitID) }
    private var fields: [MetricField] { habit?.metricFields ?? [] }
    private var field: MetricField? { fields.first { $0.id == selectedField } ?? fields.first { !$0.archived } ?? fields.first }
    private var series: MeasurementSeries {
        let start = range.days.map { Day.adding(-$0 + 1, to: Calendar.current.startOfDay(for: Date())) }
        return habit?.series(for: field?.id ?? UUID(), from: start, through: Date()) ?? MeasurementSeries(points: [])
    }
    private var selectedPoint: MeasurementPoint? {
        guard let selectedTime else { return nil }
        return series.points.min { abs($0.date.timeIntervalSince(selectedTime)) < abs($1.date.timeIntervalSince(selectedTime)) }
    }
    private var xRange: ClosedRange<Date> {
        guard let first = series.first?.date, let last = series.latest?.date else { return Date().addingTimeInterval(-86400)...Date() }
        return first == last ? first.addingTimeInterval(-43200)...last.addingTimeInterval(43200) : first...last
    }
    private var axisFormat: Date.FormatStyle {
        if let first = series.first, let last = series.latest, Calendar.current.isDate(first.date, inSameDayAs: last.date) {
            return .dateTime.hour().minute()
        }
        if let first = series.first, let last = series.latest,
           Calendar.current.component(.year, from: first.date) != Calendar.current.component(.year, from: last.date) {
            return .dateTime.month(.abbreviated).year()
        }
        return .dateTime.month(.abbreviated).day()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trends").font(.system(size: 21, weight: .bold))
                Spacer()
                if let field {
                    Menu {
                        ForEach(fields) { option in
                            Button(option.label + (option.archived ? " · archived" : "")) { selectedField = option.id; selectedTime = nil }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(field.label).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                    }.accessibilityIdentifier("chart-metric")
                }
            }
            Picker("Time range", selection: $range) {
                ForEach(TrendRange.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("chart-range")
            if let field, !series.points.isEmpty {
                let visible = series
                VStack(alignment: .leading, spacing: 4) {
                    if let point = selectedPoint ?? visible.latest {
                        Text("\(NumericValue.text(point.value))\(field.unit.isEmpty ? "" : " \(field.unit)")")
                            .font(.system(size: 27, weight: .bold, design: .rounded)).accessibilityIdentifier("chart-value")
                        Text(point.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(BloomStyle.secondary)
                    }
                }
                Chart {
                    ForEach(visible.points) { point in
                        LineMark(x: .value("Time", point.date), y: .value(field.label, point.value))
                            .interpolationMethod(.linear).foregroundStyle(habit?.tint.accent ?? BloomStyle.coral)
                        PointMark(x: .value("Time", point.date), y: .value(field.label, point.value))
                            .symbolSize(35).foregroundStyle(habit?.tint.accent ?? BloomStyle.coral)
                    }
                    if let selectedPoint {
                        RuleMark(x: .value("Selected time", selectedPoint.date)).foregroundStyle(BloomStyle.secondary.opacity(0.35))
                    }
                }
                .chartXScale(domain: xRange).chartYScale(domain: visible.valueRange)
                .chartXSelection(value: $selectedTime)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { AxisGridLine(); AxisValueLabel(format: axisFormat) } }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 205).accessibilityLabel("\(field.label) over time, \(visible.points.count) recorded values")
                .accessibilityIdentifier("measurement-chart")
                HStack(alignment: .top) {
                    summary("Entries", value: "\(visible.points.count)")
                    summary("Lowest", value: visible.minimum.map(NumericValue.text) ?? "—")
                    summary("Highest", value: visible.maximum.map(NumericValue.text) ?? "—")
                    summary("Change", value: visible.change.map { ($0 > 0 ? "+" : "") + NumericValue.text($0) } ?? "—")
                }
                Text("Each point is a recorded entry. Tap or drag across the chart to see its value and time.")
                    .font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 35)).foregroundStyle(habit?.tint.accent ?? BloomStyle.coral)
                    Text("No values in this period").font(.subheadline.weight(.medium))
                    Text("Record a value or choose another range.").font(.caption).foregroundStyle(BloomStyle.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 32)
            }
        }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24))
            .onChange(of: range) { _, _ in selectedTime = nil }
    }

    private func summary(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10)).foregroundStyle(BloomStyle.secondary)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
