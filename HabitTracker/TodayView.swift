import SwiftUI
import HabitCore

private enum HabitFilter: String, CaseIterable { case all = "All", remaining = "Remaining", completed = "Completed" }

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastToday = Date()
    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var filter: HabitFilter = .all
    @State private var selectedHabit: Habit?
    @State private var editingHabit: Habit?
    @State private var showMood = false
    @State private var showCompleteAll = false
    @State private var showDatePicker = false
    @State private var showActivity = false
    @State private var addingForDay = false
    @State private var showUpcoming = false
    @State private var loggingHabit: Habit?

    private var due: [Habit] { store.activeHabits.filter { $0.isScheduled(on: date) } }
    private var visible: [Habit] {
        due.filter { filter == .all || (filter == .completed ? $0.isComplete(on: date) : !$0.isComplete(on: date)) }
    }
    private var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }
    private var allDone: Bool { !due.isEmpty && due.allSatisfy { $0.isComplete(on: date) } }
    private var quickTasks: [Habit] { due.filter { !$0.isNumeric && !$0.isComplete(on: date) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(HabitFilter.allCases, id: \.self) { item in
                        Button { filter = item } label: {
                            if filter == item { Label(item.rawValue, systemImage: "checkmark") }
                            else { Text(item.rawValue) }
                        }
                    }
                    Divider()
                    Button(isFuture ? "Schedule a task for this day" : "Add one-off for this day", systemImage: "plus") { addingForDay = true }
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue).font(.system(size: 15, weight: .medium))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }.foregroundStyle(.white).padding(.horizontal, 13).padding(.vertical, 10)
                        .background(Color(hex: 0xFF7D88), in: Capsule())
                }.accessibilityLabel("Filter habits")
                Spacer()
                Button { showDatePicker = true } label: {
                    Text(date.dayTitle).font(.system(size: 21, weight: .bold)).foregroundStyle(BloomStyle.ink)
                }.accessibilityLabel("Choose date, \(date.dayTitle)")
                Spacer()
                Button { showMood = true } label: {
                    Text(store.document.moods[Day.key(date)] ?? "🙂").font(.system(size: 29))
                        .frame(width: 47, height: 44)
                }.accessibilityLabel("Log your mood").disabled(isFuture)
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 19)

            weekStrip.padding(.horizontal, 16).padding(.bottom, 17)

            ScrollView {
                LazyVStack(spacing: 14) {
                    if visible.isEmpty {
                        VStack(spacing: 13) {
                            Text(allDone ? "🌷" : "🌱").font(.system(size: 50))
                            Text(emptyTitle).font(.system(size: 22, weight: .semibold))
                            Text(emptyMessage).font(.subheadline).foregroundStyle(BloomStyle.secondary)
                                .multilineTextAlignment(.center)
                            if filter != .all {
                                Button("Show all habits") { filter = .all }.font(.subheadline.bold())
                            }
                        }.padding(.horizontal, 22).padding(.vertical, 60).frame(maxWidth: .infinity)
                    }
                    ForEach(visible) { habit in
                        habitRow(habit)
                            .contextMenu {
                                Button("Edit habit", systemImage: "pencil") { editingHabit = habit }
                                Button("Archive habit", systemImage: "archivebox") { store.archive(habit.id) }
                            }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 16)
            }.scrollIndicators(.hidden)

            HStack {
                Button { showActivity = true } label: {
                    Label("Timeline", systemImage: "clock").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BloomStyle.secondary).padding(.vertical, 14)
                }.accessibilityLabel("All activity timeline")
                Spacer(minLength: 6)
                Button { showUpcoming = true } label: {
                    Label("Upcoming", systemImage: "calendar").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BloomStyle.secondary).padding(.vertical, 14)
                }.accessibilityLabel("Upcoming tasks")
                Spacer(minLength: 6)
                Button { showCompleteAll = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(BloomStyle.mint)
                        Text(allDone ? "All done" : due.contains(where: \.isNumeric) ? "Complete tasks" : "Complete all").foregroundStyle(BloomStyle.secondary)
                    }.font(.system(size: 13, weight: .medium)).padding(.vertical, 14)
                }.disabled(quickTasks.isEmpty || isFuture).accessibilityIdentifier("complete-all")
            }.padding(.horizontal, 23).padding(.top, 4)
        }
        .background(.white)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshDay() } }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in refreshDay() }
        .sheet(item: $selectedHabit) { habit in HabitDetailView(habitID: habit.id, date: date) }
        .sheet(item: $editingHabit) { HabitEditor(existing: $0) }
        .sheet(item: $loggingHabit) { LogEditor(habitID: $0.id, date: date) }
        .sheet(isPresented: $showActivity) { ActivityView() }
        .sheet(isPresented: $showUpcoming) { UpcomingTasksView() }
        .sheet(isPresented: $addingForDay) { HabitEditor(initialDate: date, initialOneOff: true) }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Select a day", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("Your days").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDatePicker = false } } }
            }.presentationDetents([.medium, .large])
        }
        .confirmationDialog("How did this day feel?", isPresented: $showMood, titleVisibility: .visible) {
            ForEach(["😄", "🙂", "😐", "😔", "😴"], id: \.self) { mood in
                Button(mood) { store.setMood(mood, on: date) }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Complete the remaining check-in tasks for \(date.dayTitle.lowercased())? Value trackers require recorded values.", isPresented: $showCompleteAll, titleVisibility: .visible) {
            Button("Complete \(quickTasks.count) tasks") { withAnimation { store.completeAll(on: date) } }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(Day.week(containing: date), id: \.self) { day in
                let selected = Calendar.current.isDate(day, inSameDayAs: date)
                let scheduled = store.document.habits.filter { $0.isScheduled(on: day) }
                let rate = scheduled.isEmpty ? 0 : scheduled.reduce(0) { $0 + $1.progress(on: day) } / Double(scheduled.count)
                Button { withAnimation(.easeInOut(duration: 0.2)) { date = day } } label: {
                    VStack(spacing: 12) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).prefix(2))
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? BloomStyle.ink : BloomStyle.secondary)
                        Text(day.formatted(.dateTime.day())).font(.system(size: 15))
                            .foregroundStyle(BloomStyle.secondary)
                            .frame(width: 31, height: 31)
                            .background { ProgressRing(progress: rate, lineWidth: 2) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background { Capsule().strokeBorder(selected ? BloomStyle.pinkTrack : .clear, lineWidth: 1) }
                        .padding(.horizontal, 2)
                }.accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 25).onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height) {
                date = Day.adding(value.translation.width < 0 ? 7 : -7, to: date)
            }
        })
    }

    private func refreshDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if Calendar.current.isDate(date, inSameDayAs: lastToday) { date = today }
        lastToday = today
    }

    private func habitRow(_ habit: Habit) -> some View {
        let completed = habit.isComplete(on: date)
        return HStack(spacing: 0) {
            Button { selectedHabit = habit } label: {
                HStack(spacing: 12) {
                    Text(habit.emoji).font(.system(size: 27)).frame(width: 33)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.title).font(.system(size: 17, weight: .medium)).foregroundStyle(BloomStyle.ink)
                            .multilineTextAlignment(.leading).lineLimit(2)
                        if let last = habit.entry(on: date).logs.max(by: { $0.occurredAt < $1.occurredAt }) {
                            if habit.isNumeric { Text(habit.valueSummary(for: last)).font(.system(size: 12)).foregroundStyle(BloomStyle.ink).lineLimit(2) }
                            Text("\(habit.entry(on: date).logs.count) \(habit.entry(on: date).logs.count == 1 ? "check-in" : "check-ins") · \(last.occurredAt.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
                        } else {
                            Text(habit.effectiveSchedule.summary()).font(.system(size: 11)).foregroundStyle(BloomStyle.secondary)
                        }
                    }
                    Spacer(minLength: 3)
                }.padding(.leading, 16).padding(.vertical, 18).frame(maxWidth: .infinity, minHeight: 72)
            }.buttonStyle(.plain).accessibilityIdentifier("habit-\(habit.title)")
            Button {
                if habit.isNumeric { loggingHabit = habit }
                else if completed { selectedHabit = habit }
                else { withAnimation(.spring(response: 0.3)) { store.setCount(habit.target, for: habit.id, on: date) } }
            } label: {
                HStack(spacing: 5) {
                    if habit.isNumeric { Image(systemName: "plus.circle.fill").foregroundStyle(habit.tint.accent) }
                    else if completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(habit.tint.accent) }
                    else {
                        Text("\(habit.entry(on: date).count)/\(habit.target)\(habit.unit == "min" ? "min" : "")")
                            .foregroundStyle(BloomStyle.ink)
                    }
                }.font(.system(size: 16)).frame(minWidth: 49, minHeight: 60).padding(.trailing, 14)
            }.buttonStyle(.plain).disabled(isFuture)
                .accessibilityLabel(habit.isNumeric ? "Record values for \(habit.title)" : completed ? "View \(habit.title) entries" : "Complete \(habit.title)")
        }.background(habit.tint.background, in: RoundedRectangle(cornerRadius: 15))
    }

    private var emptyTitle: String {
        if filter == .completed { return "Room for your first win" }
        if allDone { return "You showed up!" }
        return "A little breathing room"
    }
    private var emptyMessage: String {
        if filter == .completed { return "Your completed habits will appear here." }
        if allDone { return "Every habit for this day is complete." }
        return "No habits scheduled for this day. Add one with the + button, or choose another day."
    }
}
