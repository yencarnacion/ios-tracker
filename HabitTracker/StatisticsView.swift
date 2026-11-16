import SwiftUI
import HabitCore

struct StatisticsView: View {
    @Environment(HabitStore.self) private var store
    var initialHabitID: UUID?
    @State private var selectedID: UUID?
    @State private var month = Date()
    @State private var selectedDay = Date()
    @State private var showDay = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 7)
    private var habits: [Habit] { store.document.habits.filter { selectedID == nil || $0.id == selectedID } }
    private var monthDays: [Date] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        return Day.range(from: interval.start, through: Day.adding(-1, to: interval.end))
    }
    private var summary: HabitSummary { HabitSummary(habits: habits, days: monthDays) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("Your progress").font(.system(size: 24, weight: .bold))
                    Spacer()
                    Menu {
                        Button("All items") { selectedID = nil }
                        ForEach(store.document.habits) { habit in Button("\(habit.emoji) \(habit.title)") { selectedID = habit.id } }
                    } label: {
                        HStack(spacing: 5) {
                            Text(selectedID.flatMap { store.habit($0)?.emoji } ?? "🌸")
                            Image(systemName: "chevron.down").font(.caption)
                        }.padding(10).background(.white, in: Capsule())
                    }.accessibilityLabel("Filter statistics")
                }.padding(.top, 18)

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        chip("All", id: nil)
                        ForEach(store.document.habits) { habit in chip(habit.emoji, id: habit.id) }
                    }.padding(.vertical, 2)
                }.scrollIndicators(.hidden)

                VStack(spacing: 15) {
                    HStack {
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 38, height: 35) }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 38, height: 35) }
                            .accessibilityLabel("Next month")
                    }.foregroundStyle(BloomStyle.ink)
                    LazyVGrid(columns: columns, spacing: 13) {
                        ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                            Text(day).font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity)
                        }
                        ForEach(Day.monthGrid(containing: month), id: \.self) { day in calendarCell(day) }
                    }
                }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 25))

                VStack(spacing: 26) {
                    ZStack {
                        ProgressRing(progress: summary.rate, lineWidth: 10)
                        VStack(spacing: 7) {
                            Text(summary.rate, format: .percent.precision(.fractionLength(1)))
                                .font(.system(size: 37, weight: .bold, design: .rounded))
                            Text("Monthly rate").font(.system(size: 15)).foregroundStyle(BloomStyle.secondary)
                            Text("\(summary.completed) of \(summary.scheduled) goals met").font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
                        }
                    }.frame(width: 187, height: 187).padding(.top, 10)
                    HStack {
                        metric("Best habit streak", value: "\(habits.filter { !$0.isOneOff }.map { $0.bestStreak() }.max() ?? 0)", symbol: "medal.fill", color: .orange)
                        metric("Perfect days", value: "\(summary.perfectDays)", symbol: "calendar.badge.checkmark", color: .blue)
                    }
                    HStack {
                        metric("Goals met", value: "\(summary.completed)", symbol: "checkmark.seal.fill", color: BloomStyle.mint)
                        metric("Check-ins", value: "\(logCount)", symbol: "clock.fill", color: .purple)
                    }
                }.padding(24).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 25))
                Text("Tap a day to see what you did and when.").font(.caption).foregroundStyle(BloomStyle.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 20)
        }.background(BloomStyle.canvas).scrollIndicators(.hidden)
            .onAppear { selectedID = initialHabitID }
            .sheet(isPresented: $showDay) { DayHistoryView(date: selectedDay, habitID: selectedID) }
    }

    private var logCount: Int {
        habits.flatMap(\.allLogs).filter { Calendar.current.isDate($0.occurredAt, equalTo: month, toGranularity: .month) }.count
    }

    private func chip(_ title: String, id: UUID?) -> some View {
        Button { selectedID = id } label: {
            Text(title).font(.system(size: id == nil ? 13 : 25, weight: .semibold))
                .foregroundStyle(selectedID == id ? BloomStyle.coral : BloomStyle.secondary)
                .frame(width: 43, height: 43).background(selectedID == id ? BloomStyle.pinkTrack.opacity(0.6) : .white, in: Circle())
        }.accessibilityLabel(id.flatMap { store.habit($0)?.title } ?? "All items")
            .accessibilityAddTraits(selectedID == id ? .isSelected : [])
    }

    private func calendarCell(_ day: Date) -> some View {
        let due = habits.filter { $0.isScheduled(on: day) }
        let future = Calendar.current.startOfDay(for: day) > Calendar.current.startOfDay(for: Date())
        let rate = due.isEmpty ? 0 : due.reduce(0) { $0 + $1.progress(on: day) } / Double(due.count)
        let inMonth = Calendar.current.isDate(day, equalTo: month, toGranularity: .month)
        return Button { selectedDay = day; showDay = true } label: {
            Text(day.formatted(.dateTime.day())).font(.system(size: 14))
                .foregroundStyle(inMonth ? BloomStyle.ink : BloomStyle.secondary.opacity(0.5))
                .frame(maxWidth: .infinity).frame(height: 32)
                .background {
                    ProgressRing(progress: future ? 0 : rate,
                                 track: future || due.isEmpty ? BloomStyle.canvas : BloomStyle.pinkTrack, lineWidth: 1.6)
                        .frame(width: 31, height: 31)
                }
                .overlay(alignment: .bottom) {
                    if Calendar.current.isDateInToday(day) { Circle().fill(BloomStyle.ink).frame(width: 3, height: 3).offset(y: 6) }
                }
        }.accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(Int(rate * 100)) percent")
    }

    private func metric(_ title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 21)).foregroundStyle(color)
                .frame(width: 45, height: 45).background(color.opacity(0.08), in: Circle())
            Text(value).font(.system(size: 29, weight: .bold, design: .rounded))
            Text(title).font(.system(size: 12)).foregroundStyle(BloomStyle.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func moveMonth(_ value: Int) { month = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month }
}

struct DayHistoryView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: Date
    var habitID: UUID?
    @State private var selectedHabit: Habit?
    @State private var adding = false
    private var habits: [Habit] {
        store.document.habits.filter { (habitID == nil || $0.id == habitID) && ($0.isScheduled(on: date) || !$0.entry(on: date).logs.isEmpty) }
    }
    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty { ContentUnavailableView("A quiet day", systemImage: "leaf", description: Text("No items recorded for this day.")) }
                ForEach(habits) { habit in
                    Section {
                        Button { selectedHabit = habit } label: {
                            HStack {
                                Text("\(habit.emoji) \(habit.title)").foregroundStyle(BloomStyle.ink)
                                Spacer()
                                Text("\(habit.entry(on: date).count)/\(habit.target)").foregroundStyle(habit.tint.accent)
                            }
                        }
                        ForEach(habit.entry(on: date).logs.sorted { $0.occurredAt < $1.occurredAt }) { log in
                            HStack {
                                Text(log.occurredAt.formatted(date: .omitted, time: .shortened)).foregroundStyle(BloomStyle.secondary)
                                Spacer()
                                Text("+\(log.amount) \(habit.unit)")
                            }.font(.subheadline)
                        }
                    }
                }
            }.navigationTitle(date.formatted(date: .abbreviated, time: .omitted)).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Button { adding = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add item for this day")
                    }
                }
                .sheet(item: $selectedHabit) { HabitDetailView(habitID: $0.id, date: date) }
                .sheet(isPresented: $adding) { HabitEditor(initialDate: date, initialOneOff: true) }
        }
    }
}
