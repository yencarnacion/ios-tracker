import SwiftUI
import HabitCore

struct NumericTrackerDetail: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    let date: Date
    @State private var logging = false
    @State private var editing = false
    @State private var editingLog: HabitLog?
    @State private var archive = false
    private var habit: Habit? { store.habit(habitID) }
    private var future: Bool { Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        if let habit {
            VStack(spacing: 0) {
                HStack {
                    RoundButton(symbol: "chevron.left", label: "Close habit") { dismiss() }
                    Spacer()
                    Text("\(habit.emoji) \(habit.title)").font(.system(size: 20, weight: .bold)).lineLimit(2).multilineTextAlignment(.center)
                    Spacer()
                    Menu {
                        Button("Edit item", systemImage: "pencil") { editing = true }
                        Button("Archive item", systemImage: "archivebox") { archive = true }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 21, weight: .bold))
                            .frame(width: 46, height: 46).background(.white.opacity(0.8), in: Circle())
                    }.accessibilityLabel("Item options")
                }.padding(.horizontal, 20).padding(.top, 20)
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 5) {
                            Text(date.dayTitle).font(.system(size: 15, weight: .semibold))
                            Text(habit.effectiveSchedule.summary()).font(.caption).foregroundStyle(BloomStyle.secondary)
                            Text("\(habit.entry(on: date).logs.count) \(habit.entry(on: date).logs.count == 1 ? "entry" : "entries") on this day").font(.caption).foregroundStyle(BloomStyle.secondary)
                                .accessibilityIdentifier("numeric-entry-count")
                            Text("Goal: \(habit.target) \(habit.target == 1 ? "entry" : "entries") on each due day").font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
                        }.padding(.top, 15)
                        HStack {
                            Spacer()
                            PrimaryButton(title: "Record values", symbol: "plus") { logging = true }
                                .disabled(future).accessibilityIdentifier("log-values")
                            Spacer()
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Latest values").font(.system(size: 18, weight: .semibold))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(2, habit.activeMetrics.count)), spacing: 12) {
                                ForEach(habit.activeMetrics) { field in
                                    let latest = habit.series(for: field.id, through: Date()).latest
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(field.label).font(.system(size: 12, weight: .medium)).foregroundStyle(BloomStyle.secondary)
                                        Text(latest.map { NumericValue.text($0.value) } ?? "—")
                                            .font(.system(size: 26, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                                        Text(latest.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? "No entry yet")
                                            .font(.system(size: 10)).foregroundStyle(BloomStyle.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(15)
                                        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                        MetricChartView(habitID: habitID)
                        VStack(alignment: .leading, spacing: 13) {
                            Text("\(date.dayTitle) · timeline").font(.system(size: 19, weight: .semibold))
                            let logs = habit.entry(on: date).logs.sorted { $0.occurredAt > $1.occurredAt }
                            if logs.isEmpty {
                                Text(future ? "This day hasn’t arrived yet." : "Record your first values for this day.").font(.subheadline).foregroundStyle(BloomStyle.secondary)
                            }
                            ForEach(logs) { log in
                                Button { editingLog = log } label: { LogRow(log: log, habit: habit) }
                                    .buttonStyle(.plain).accessibilityIdentifier("measurement-entry-\(log.id.uuidString)")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                    }.padding(.horizontal, 20).padding(.bottom, 25)
                }.scrollIndicators(.hidden)
            }.foregroundStyle(BloomStyle.ink)
                .background(LinearGradient(colors: [habit.tint.background, BloomStyle.canvas], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                .sheet(isPresented: $logging) { LogEditor(habitID: habitID, date: date) }
                .sheet(isPresented: $editing) { HabitEditor(existing: store.habit(habitID)) }
                .sheet(item: $editingLog) { LogEditor(habitID: habitID, date: $0.occurredAt, existing: $0) }
                .confirmationDialog("Archive this tracker? All values and charts will be kept.", isPresented: $archive, titleVisibility: .visible) {
                    Button("Archive") { store.archive(habitID); dismiss() }
                    Button("Cancel", role: .cancel) { }
                }
        }
    }
}
