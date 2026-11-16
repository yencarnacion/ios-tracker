import SwiftUI
import HabitCore

struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    var date: Date
    @State private var showEditor = false
    @State private var showLog = false
    @State private var editingLog: HabitLog?
    @State private var showMemo = false
    @State private var showStats = false
    @State private var confirmArchive = false
    @State private var memo = ""
    private var habit: Habit? { store.habit(habitID) }
    private var isFuture: Bool { Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        if let habit {
            VStack(spacing: 0) {
                HStack {
                    RoundButton(symbol: "chevron.left", label: "Close habit") { dismiss() }
                    Spacer()
                    Text("\(habit.emoji) \(habit.title)").font(.system(size: 20, weight: .bold))
                        .lineLimit(2).multilineTextAlignment(.center)
                    Spacer()
                    Menu {
                        Button("Edit item", systemImage: "pencil") { showEditor = true }
                        Button("Archive item", systemImage: "archivebox") { confirmArchive = true }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 21, weight: .bold))
                            .foregroundStyle(BloomStyle.ink).frame(width: 46, height: 46)
                            .background(.white.opacity(0.7), in: Circle())
                            .overlay(Circle().strokeBorder(.black.opacity(0.07)))
                    }.accessibilityLabel("Item options")
                }.padding(.horizontal, 20).padding(.top, 20)

                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 5) {
                            Text(date.dayTitle).font(.system(size: 14, weight: .medium)).foregroundStyle(BloomStyle.secondary)
                            if habit.oneOffDate != nil { Text("Just this day · never repeats").font(.caption).foregroundStyle(BloomStyle.secondary) }
                        }.padding(.top, 19)

                        ZStack {
                            ProgressRing(progress: habit.progress(on: date), color: habit.tint.accent, track: .white, lineWidth: 15)
                            VStack(spacing: 14) {
                                Text(habit.emoji).font(.system(size: 37))
                                Text("\(habit.entry(on: date).count)").font(.system(size: 52, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText()).accessibilityIdentifier("habit-count")
                                Text("/ \(habit.target)\(habit.unit.isEmpty ? "" : " \(habit.unit)")")
                                    .font(.system(size: 17)).foregroundStyle(BloomStyle.secondary)
                            }
                        }.frame(width: 238, height: 238).padding(.vertical, 12)

                        HStack(spacing: 17) {
                            Button {
                                if Calendar.current.isDateInToday(date) {
                                    withAnimation { store.record(HabitLog(), for: habitID) }
                                } else { showLog = true }
                            } label: {
                                Label(Calendar.current.isDateInToday(date) ? "Add 1 now" : "Add 1", systemImage: "plus").font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white).padding(.horizontal, 23).padding(.vertical, 15)
                                    .background(habit.tint.accent, in: Capsule())
                            }.accessibilityIdentifier("add-one").disabled(isFuture)
                            Button { showLog = true } label: {
                                Image(systemName: "clock").font(.system(size: 23))
                                    .foregroundStyle(habit.tint.accent).frame(width: 51, height: 51)
                                    .background(.white.opacity(0.8), in: Circle())
                            }.accessibilityLabel("Log amount and time").disabled(isFuture)
                        }
                        Text(Calendar.current.isDateInToday(date) ? "Every check-in keeps its own time." : "Entries are saved to \(date.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.system(size: 12)).foregroundStyle(BloomStyle.secondary)

                        HStack(spacing: 45) {
                            Button { memo = habit.entry(on: date).note; showMemo = true } label: {
                                Label("Memo", systemImage: "square.and.pencil").foregroundStyle(Color(hex: 0xB47E2A))
                            }.disabled(isFuture)
                            Button { showStats = true } label: {
                                Label("Stats", systemImage: "chart.bar.fill").foregroundStyle(Color(hex: 0x3897B0))
                            }
                        }.font(.system(size: 14)).padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Your timeline").font(.system(size: 19, weight: .semibold))
                                Spacer()
                                Text("\(habit.entry(on: date).logs.count) entries").font(.caption).foregroundStyle(BloomStyle.secondary)
                            }
                            if habit.entry(on: date).logs.isEmpty {
                                Label("Your first little step starts here.", systemImage: "clock")
                                    .font(.subheadline).foregroundStyle(BloomStyle.secondary).padding(.vertical, 14)
                            }
                            ForEach(habit.entry(on: date).logs.sorted { $0.occurredAt > $1.occurredAt }) { log in
                                Button { editingLog = log } label: {
                                    LogRow(log: log, habit: habit)
                                }.buttonStyle(.plain).accessibilityLabel("Edit entry at \(log.occurredAt.formatted(date: .omitted, time: .shortened))")
                            }
                            if !habit.entry(on: date).note.isEmpty {
                                Label(habit.entry(on: date).note, systemImage: "note.text")
                                    .font(.subheadline).foregroundStyle(BloomStyle.secondary).padding(.top, 5)
                            }
                        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 23))
                            .padding(.horizontal, 20).padding(.bottom, 25)
                    }
                }.scrollIndicators(.hidden)
            }
            .foregroundStyle(BloomStyle.ink)
            .background(LinearGradient(colors: [habit.tint.background, BloomStyle.canvas], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .sheet(isPresented: $showEditor) { HabitEditor(existing: store.habit(habitID)) }
            .sheet(isPresented: $showLog) { LogEditor(habitID: habitID, date: date) }
            .sheet(item: $editingLog) { LogEditor(habitID: habitID, date: date, existing: $0) }
            .sheet(isPresented: $showStats) {
                NavigationStack {
                    StatisticsView(initialHabitID: habitID)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showStats = false } } }
                }
            }
            .sheet(isPresented: $showMemo) {
                NavigationStack {
                    TextEditor(text: $memo).padding().navigationTitle("A note for this day").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showMemo = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { store.setNote(memo, for: habitID, on: date); showMemo = false }
                            }
                        }
                }.presentationDetents([.medium, .large])
            }
            .confirmationDialog("Archive this item? Your history will be kept.", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archive") { store.archive(habitID); dismiss() }
                Button("Cancel", role: .cancel) { }
            }
        } else { ContentUnavailableView("Item unavailable", systemImage: "leaf") }
    }
}

struct LogRow: View {
    let log: HabitLog
    let habit: Habit
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock").font(.system(size: 15)).foregroundStyle(habit.tint.accent)
                .frame(width: 32, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(log.occurredAt.formatted(date: .omitted, time: .standard)).font(.system(size: 16, weight: .semibold))
                if !log.note.isEmpty { Text(log.note).font(.system(size: 13)).foregroundStyle(BloomStyle.secondary) }
            }
            Spacer()
            Text("+\(log.amount)\(habit.unit.isEmpty ? "" : " \(habit.unit)")")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(BloomStyle.ink)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(BloomStyle.secondary)
        }.foregroundStyle(BloomStyle.ink).padding(12)
            .background(habit.tint.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct LogEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    var date: Date
    var existing: HabitLog?
    @State private var timestamp = Date()
    @State private var amount = "1"
    @State private var note = ""
    @State private var showDelete = false
    private var habit: Habit? { store.habit(habitID) }
    private var valid: Bool { (1...9999).contains(Int(amount) ?? 0) && timestamp <= Date() }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount\(habit?.unit.isEmpty == false ? " (\(habit!.unit))" : "")")
                        TextField("1", text: $amount).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("log-amount")
                    }
                    DatePicker("When", selection: $timestamp, in: allowedRange,
                               displayedComponents: habit?.oneOffDate == nil ? [.date, .hourAndMinute] : [.hourAndMinute])
                        .accessibilityIdentifier("log-time")
                    TextField("Add a note (optional)", text: $note, axis: .vertical).lineLimit(3...6)
                        .onChange(of: note) { _, value in note = String(value.prefix(5000)) }
                } header: { Text("\(habit?.emoji ?? "") \(habit?.title ?? "Entry")") }
                footer: {
                    Text(habit?.oneOffDate == nil ? "This check-in has its own timestamp. Changing its date moves it to that day’s timeline." : "This one-off belongs to \(date.formatted(date: .abbreviated, time: .omitted)). Every check-in keeps its own time on that day.")
                }
                if existing != nil {
                    Section { Button("Delete entry", role: .destructive) { showDelete = true } }
                }
            }
            .navigationTitle(existing == nil ? "Log a little progress" : "Edit entry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let log = HabitLog(id: existing?.id ?? UUID(), occurredAt: timestamp, amount: Int(amount) ?? 1, note: note)
                        store.record(log, for: habitID); dismiss()
                    }.disabled(!valid).accessibilityIdentifier("save-entry")
                }
            }
            .onAppear {
                timestamp = existing?.occurredAt ?? min(Date(), Day.time(on: date, from: Date()))
                amount = String(existing?.amount ?? 1); note = existing?.note ?? ""
            }
            .confirmationDialog("Delete this check-in?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete entry", role: .destructive) {
                    if let existing { store.deleteLog(existing.id, for: habitID) }; dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var allowedRange: ClosedRange<Date> {
        if let day = habit?.oneOffDate {
            let start = Calendar.current.startOfDay(for: day)
            return start...max(start, min(Date(), Day.adding(1, to: start).addingTimeInterval(-1)))
        }
        return min(Calendar.current.startOfDay(for: habit?.createdAt ?? date), Date())...Date()
    }
}
