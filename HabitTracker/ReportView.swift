import SwiftUI
import HabitCore

private enum ReportPeriod: String, CaseIterable { case weekly = "Weekly", monthly = "Monthly", yearly = "Yearly" }

struct ReportView: View {
    @Environment(HabitStore.self) private var store
    @State private var period: ReportPeriod = .weekly
    @State private var anchor = Date()
    @State private var selectedHabit: Habit?
    @State private var selectedDate = Date()
    private var days: [Date] {
        switch period {
        case .weekly: Day.week(containing: anchor)
        case .monthly, .yearly:
            if let interval = Calendar.current.dateInterval(of: period == .monthly ? .month : .year, for: anchor) {
                Day.range(from: interval.start, through: Day.adding(-1, to: interval.end))
            } else { [] }
        }
    }
    private var habits: [Habit] { store.document.habits.filter { habit in days.contains { habit.isScheduled(on: $0) } } }
    private var summary: HabitSummary { HabitSummary(habits: habits, days: days) }
    private var buckets: [[Date]] {
        if period != .yearly { return days.map { [$0] } }
        return (1...12).map { month in days.filter { Calendar.current.component(.month, from: $0) == month } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 18) {
                    ForEach(ReportPeriod.allCases, id: \.self) { p in
                        Button { period = p } label: {
                            VStack(spacing: 7) {
                                Text(p.rawValue).font(.system(size: 16, weight: period == p ? .semibold : .regular))
                                    .foregroundStyle(period == p ? BloomStyle.ink : BloomStyle.secondary)
                                Capsule().fill(period == p ? BloomStyle.coral : .clear).frame(height: 3)
                            }
                        }
                    }
                    Spacer()
                    ShareLink(item: reportText) { Image(systemName: "square.and.arrow.up").font(.system(size: 19)) }
                        .accessibilityLabel("Share report")
                }.padding(.top, 22)

                VStack(spacing: 20) {
                    HStack(alignment: .center, spacing: 11) {
                        Text("☀️").font(.system(size: 33))
                        VStack(spacing: 2) {
                            Text("Habit Tracker").font(.system(size: 34, weight: .semibold, design: .serif)).italic().foregroundStyle(BloomStyle.coral)
                            Text("a little better, a little every day").font(.system(size: 10)).tracking(1).foregroundStyle(BloomStyle.secondary)
                        }
                        Text("🌙").font(.system(size: 29))
                    }.padding(.top, 10)
                    HStack {
                        Button { move(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.system(size: 23)) }.accessibilityLabel("Previous period")
                        Spacer()
                        Text(periodTitle).font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8).background(Color(hex: 0xFFF6BB))
                        Spacer()
                        Button { move(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.system(size: 23)) }.accessibilityLabel("Next period")
                    }
                    if habits.isEmpty {
                        ContentUnavailableView("A fresh page", systemImage: "leaf", description: Text("Your habits and one-off items will fill this report."))
                    } else { reportGrid }
                    HStack(alignment: .top) {
                        reportMetric(summary.rate.formatted(.percent.precision(.fractionLength(0))), "Goals met", color: BloomStyle.coral)
                        reportMetric("\(summary.perfectDays)", "Perfect days", color: Color(hex: 0x4FB8DE))
                        reportMetric("\(checkIns)", "Check-ins", color: BloomStyle.mint)
                    }.padding(.vertical, 8)
                    Text("Every square is a step you took.").font(.system(size: 13)).foregroundStyle(BloomStyle.secondary)
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 26))
                Text("All your history. All your progress.").font(.caption).foregroundStyle(BloomStyle.secondary)
            }.padding(.horizontal, 18).padding(.bottom, 22)
        }.scrollIndicators(.hidden)
            .sheet(item: $selectedHabit) { HabitDetailView(habitID: $0.id, date: selectedDate) }
    }

    private var reportGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Text(" ").frame(height: 32)
                ForEach(habits) { habit in
                    HStack(spacing: 5) {
                        Text(habit.emoji).font(.system(size: 17))
                        Text(habit.title).font(.system(size: 11)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(width: 94, height: 43).padding(.trailing, 5)
                        .overlay(alignment: .bottom) { Rectangle().fill(BloomStyle.canvas).frame(height: 1) }
                }
            }
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                            if let first = bucket.first {
                                Text(period == .weekly ? String(first.formatted(.dateTime.weekday(.narrow))) : period == .monthly ? first.formatted(.dateTime.day()) : first.formatted(.dateTime.month(.abbreviated)))
                                    .font(.system(size: 11)).foregroundStyle(BloomStyle.secondary).frame(width: cellWidth, height: 32)
                            }
                        }
                    }
                    ForEach(habits) { habit in
                        HStack(spacing: 0) {
                            ForEach(Array(buckets.enumerated()), id: \.offset) { _, bucket in
                                let scheduled = bucket.filter { habit.isScheduled(on: $0) }
                                let elapsed = scheduled.filter { Calendar.current.startOfDay(for: $0) <= Calendar.current.startOfDay(for: Date()) }
                                let rate = elapsed.isEmpty ? 0 : elapsed.reduce(0) { $0 + habit.progress(on: $1) } / Double(elapsed.count)
                                Button {
                                    if period != .yearly, let day = bucket.first { selectedDate = day; selectedHabit = habit }
                                } label: {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(scheduled.isEmpty ? .clear : rate > 0 ? habit.tint.accent.opacity(max(0.25, rate)) : Color(hex: 0xF0F1F3))
                                        .frame(width: cellWidth - 8, height: 24)
                                        .overlay { if rate >= 1 { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) } }
                                        .frame(width: cellWidth, height: 43)
                                        .overlay(alignment: .bottom) { Rectangle().fill(BloomStyle.canvas).frame(height: 1) }
                                }.disabled(scheduled.isEmpty || period == .yearly)
                                    .accessibilityLabel("\(habit.title), \(bucket.first?.formatted(date: .abbreviated, time: .omitted) ?? ""), \(Int(rate * 100)) percent")
                            }
                        }
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }

    private var cellWidth: CGFloat { period == .weekly ? 29 : 34 }
    private var checkIns: Int {
        let keys = Set(days.map { Day.key($0) })
        return habits.flatMap(\.allLogs).filter { keys.contains(Day.key($0.occurredAt)) }.count
    }
    private var periodTitle: String {
        switch period {
        case .weekly: "\(days.first?.formatted(.dateTime.month(.defaultDigits).day()) ?? "") – \(days.last?.formatted(.dateTime.month(.defaultDigits).day()) ?? "")"
        case .monthly: anchor.formatted(.dateTime.month(.wide).year())
        case .yearly: anchor.formatted(.dateTime.year())
        }
    }
    private func reportMetric(_ value: String, _ title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 33, weight: .bold, design: .rounded)).foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
        }.frame(maxWidth: .infinity)
    }
    private func move(_ amount: Int) {
        anchor = Calendar.current.date(byAdding: period == .weekly ? .weekOfYear : period == .monthly ? .month : .year, value: amount, to: anchor) ?? anchor
    }
    private var reportText: String {
        "ios-tracker · \(periodTitle)\n\(summary.rate.formatted(.percent.precision(.fractionLength(0)))) goals met · \(checkIns) check-ins · \(summary.perfectDays) perfect days\n\n" + habits.map { habit in
            let s = HabitSummary(habits: [habit], days: days)
            return "\(habit.emoji) \(habit.title): \(s.completed)/\(s.scheduled) goals met"
        }.joined(separator: "\n")
    }
}
