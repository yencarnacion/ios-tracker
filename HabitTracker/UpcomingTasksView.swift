import SwiftUI
import HabitCore

private struct UpcomingTask: Identifiable {
    let habit: Habit
    let date: Date
    var id: UUID { habit.id }
}

struct UpcomingTasksView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UpcomingTask?
    @State private var adding = false
    private var tasks: [UpcomingTask] {
        let tomorrow = Day.adding(1, to: Calendar.current.startOfDay(for: Date()))
        return store.activeHabits.compactMap { habit in
            habit.nextScheduledDate(onOrAfter: tomorrow).map { UpcomingTask(habit: habit, date: $0) }
        }.sorted { $0.date == $1.date ? $0.habit.title.localizedStandardCompare($1.habit.title) == .orderedAscending : $0.date < $1.date }
    }
    private var dates: [Date] { Array(Set(tasks.map(\.date))).sorted() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The next occurrence of each active task, starting tomorrow.").font(.subheadline).foregroundStyle(BloomStyle.secondary)
                }
                if tasks.isEmpty {
                    ContentUnavailableView("A little room ahead", systemImage: "calendar", description: Text("Schedule a future task or a repeating routine with the + button."))
                }
                ForEach(dates, id: \.self) { date in
                    Section {
                        ForEach(tasks.filter { $0.date == date }) { task in
                            Button { selected = task } label: {
                                HStack(spacing: 13) {
                                    Text(task.habit.emoji).font(.system(size: 28))
                                        .frame(width: 46, height: 48).background(task.habit.tint.background, in: RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(task.habit.title).foregroundStyle(BloomStyle.ink)
                                        Text(task.habit.effectiveSchedule.summary()).font(.caption).foregroundStyle(BloomStyle.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(BloomStyle.secondary)
                                }.padding(.vertical, 4)
                            }.accessibilityIdentifier("upcoming-\(task.habit.title)")
                        }
                    } header: { Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())) }
                }
            }
            .navigationTitle("Upcoming").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Schedule a task")
                }
            }
            .sheet(item: $selected) { HabitDetailView(habitID: $0.habit.id, date: $0.date) }
            .sheet(isPresented: $adding) { HabitEditor(initialDate: Day.adding(1, to: Date()), initialOneOff: true) }
        }
    }
}
