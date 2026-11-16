import SwiftUI
import HabitCore

private struct ActivityItem: Identifiable {
    var habit: Habit
    var log: HabitLog
    var id: UUID { log.id }
}

struct ActivityView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selection: ActivityItem?
    private var items: [ActivityItem] {
        store.document.habits.flatMap { habit in habit.allLogs.map { ActivityItem(habit: habit, log: $0) } }
            .filter { search.isEmpty || $0.habit.title.localizedCaseInsensitiveContains(search) || $0.log.note.localizedCaseInsensitiveContains(search) }
            .sorted { $0.log.occurredAt > $1.log.occurredAt }
    }
    private var days: [String] { Array(Set(items.map { Day.key($0.log.occurredAt) })).sorted(by: >) }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty { ContentUnavailableView("Your moments, saved", systemImage: "clock", description: Text("Every check-in will appear here with the time you did it.")) }
                ForEach(days, id: \.self) { key in
                    Section {
                        ForEach(items.filter { Day.key($0.log.occurredAt) == key }) { item in
                            Button { selection = item } label: {
                                HStack(spacing: 12) {
                                    Text(item.habit.emoji).font(.system(size: 28))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.habit.title).foregroundStyle(BloomStyle.ink)
                                        Text(item.log.occurredAt.formatted(date: .omitted, time: .standard))
                                            .font(.subheadline).foregroundStyle(BloomStyle.secondary)
                                        if item.habit.isNumeric { Text(item.habit.valueSummary(for: item.log)).font(.subheadline).foregroundStyle(BloomStyle.ink) }
                                        if !item.log.note.isEmpty { Text(item.log.note).font(.caption).foregroundStyle(BloomStyle.secondary) }
                                    }
                                    Spacer()
                                    if !item.habit.isNumeric { Text("+\(item.log.amount) \(item.habit.unit)").font(.subheadline).foregroundStyle(BloomStyle.ink) }
                                }.padding(.vertical, 5)
                            }
                        }
                    } header: { Text((Day.date(key) ?? Date()).formatted(date: .complete, time: .omitted)) }
                }
            }
            .searchable(text: $search, prompt: "Find an item or note")
            .navigationTitle("Your timeline").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selection) { LogEditor(habitID: $0.habit.id, date: $0.log.occurredAt, existing: $0.log) }
        }
    }
}
