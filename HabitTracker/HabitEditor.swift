import SwiftUI
import HabitCore

struct HabitEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Habit?
    var initialDate: Date = Date()
    var initialOneOff: Bool = false
    @State private var title = ""
    @State private var emoji = "🌟"
    @State private var tint: HabitTint = .mint
    @State private var target = 1
    @State private var unit = ""
    @State private var weekdays = Set(1...7)
    @State private var oneOff = false
    @State private var startDate = Date()
    @State private var logOnSave = true
    @State private var firstLogTime = Date()
    @State private var firstAmount = "1"
    @State private var reminder = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 9)) ?? Date()
    @State private var saving = false
    @State private var permissionDenied = false

    private let emojis = ["🌟", "💧", "🏃", "📖", "🌱", "☀️", "🧘", "💊", "🍎", "😴", "🎨", "💪", "🚶", "✍️", "🎯", "🧹"]
    private let weekLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let weekValues = [2, 3, 4, 5, 6, 7, 1]
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (oneOff || !weekdays.isEmpty) && !emoji.isEmpty &&
        (!(oneOff && existing == nil && logOnSave) || ((1...9999).contains(Int(firstAmount) ?? 0) && firstLogTime <= Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Item type", selection: $oneOff) {
                        Text("Repeating habit").tag(false)
                        Text("Just this day").tag(true)
                    }.pickerStyle(.segmented).disabled(existing != nil)
                    DatePicker(oneOff ? "For this day" : "Start date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                        .disabled(existing?.oneOffDate != nil && existing?.allLogs.isEmpty == false)
                    if oneOff && existing == nil {
                        Toggle("Record first check-in", isOn: $logOnSave)
                        if logOnSave {
                            DatePicker("Time", selection: $firstLogTime, in: firstLogRange, displayedComponents: .hourAndMinute)
                            HStack {
                                Text("Amount")
                                TextField("1", text: $firstAmount).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            }
                        }
                    }
                } footer: {
                    Text(oneOff ? "A one-off item stays in this day’s history and never repeats. You can log it more than once." : "Build a routine, one small step at a time.")
                }
                Section {
                    HStack(spacing: 14) {
                        Text(emoji).font(.system(size: 33)).frame(width: 58, height: 58)
                            .background(tint.background, in: RoundedRectangle(cornerRadius: 15))
                        TextField("Habit name", text: $title).font(.system(size: 20, weight: .medium))
                            .accessibilityIdentifier("habit-name")
                            .onChange(of: title) { _, new in title = String(new.prefix(80)) }
                    }.padding(.vertical, 5)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(emojis, id: \.self) { value in
                            Button { emoji = value } label: {
                                Text(value).font(.system(size: 25)).frame(width: 33, height: 36)
                                    .background(emoji == value ? tint.background : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).accessibilityLabel("Icon \(value)")
                        }
                    }.padding(.vertical, 7)
                    HStack {
                        Text("Your own icon").foregroundStyle(BloomStyle.secondary)
                        Spacer()
                        TextField("🌟", text: $emoji).multilineTextAlignment(.trailing).frame(width: 60)
                            .onChange(of: emoji) { _, new in emoji = String(new.prefix(1)) }
                    }
                } header: { Text("Make it yours") }

                Section("Color") {
                    HStack(spacing: 15) {
                        ForEach(HabitTint.allCases, id: \.self) { color in
                            Button { tint = color } label: {
                                Circle().fill(color.background).frame(width: 35, height: 35)
                                    .overlay(Circle().strokeBorder(color.accent.opacity(tint == color ? 1 : 0.3), lineWidth: tint == color ? 3 : 1))
                                    .overlay { if tint == color { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(BloomStyle.ink) } }
                            }.buttonStyle(.plain).accessibilityLabel(color.rawValue.capitalized + " color")
                                .accessibilityAddTraits(tint == color ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                }

                Section {
                    Stepper("Daily goal: \(target)", value: $target, in: 1...9999)
                    HStack {
                        Text("Unit")
                        TextField("times, min, pages…", text: $unit).multilineTextAlignment(.trailing)
                            .onChange(of: unit) { _, new in unit = String(new.prefix(20)) }
                    }
                } header: { Text("A small, doable goal") } footer: { Text("Leave the unit empty for a simple daily check-in.") }

                if !oneOff { Section {
                    HStack(spacing: 0) {
                        ForEach(Array(weekValues.enumerated()), id: \.offset) { index, value in
                            Button {
                                if weekdays.contains(value) { weekdays.remove(value) }
                                else { weekdays.insert(value) }
                            } label: {
                                Text(weekLabels[index]).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(weekdays.contains(value) ? .white : BloomStyle.secondary)
                                    .frame(maxWidth: .infinity).frame(height: 36)
                                    .background(weekdays.contains(value) ? BloomStyle.coral : BloomStyle.canvas, in: Circle())
                                    .padding(.horizontal, 2)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(Calendar.current.weekdaySymbols[value - 1])
                                .accessibilityAddTraits(weekdays.contains(value) ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                    if weekdays.isEmpty { Text("Choose at least one day.").foregroundStyle(.red).font(.caption) }
                } header: { Text("Repeat") } footer: {
                    if existing != nil { Text("Changing the goal or repeat days also updates how existing history is calculated.") }
                } }

                if !oneOff { Section {
                    Toggle("Gentle reminder", isOn: $reminder)
                        .disabled(existing?.reminderHour == nil && store.activeHabits.filter { $0.reminderHour != nil }.count >= 8)
                    if reminder { DatePicker("At", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                } footer: { Text("Optional local notifications. Up to eight habits can have reminders.") } }
            }
            .navigationTitle(existing == nil ? "A new little step" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .fontWeight(.semibold).disabled(!valid || saving).accessibilityIdentifier("save-habit")
                }
            }
            .onAppear {
                startDate = initialDate
                firstLogTime = min(Date(), Day.time(on: initialDate, from: Date()))
                oneOff = initialOneOff
                guard let h = existing else { return }
                title = h.title; emoji = h.emoji; tint = h.tint; target = h.target
                unit = h.unit; weekdays = h.weekdays; reminder = h.reminderHour != nil
                oneOff = h.oneOffDate != nil; startDate = h.oneOffDate ?? h.createdAt
                reminderTime = Calendar.current.date(from: DateComponents(hour: h.reminderHour ?? 9, minute: h.reminderMinute)) ?? Date()
            }
            .onChange(of: startDate) { _, day in firstLogTime = min(Date(), Day.time(on: day, from: firstLogTime)) }
            .alert("Reminders are off", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    dismiss()
                }
                Button("Keep habit without reminder") { dismiss() }
            } message: { Text("Your habit was saved. Enable notifications for ios-tracker in iPhone Settings to use reminders, then turn the habit’s reminder on again.") }
        }
    }

    private func save() async {
        saving = true
        let allowed = reminder && !oneOff ? await ReminderScheduler.requestAccess() : false
        var habit = existing ?? Habit(title: title)
        habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.emoji = emoji; habit.tint = tint; habit.target = target
        habit.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.weekdays = oneOff ? Set(1...7) : weekdays
        habit.createdAt = Calendar.current.startOfDay(for: startDate)
        habit.oneOffDate = oneOff ? Calendar.current.startOfDay(for: startDate) : nil
        habit.reminderHour = reminder && allowed && !oneOff ? Calendar.current.component(.hour, from: reminderTime) : nil
        habit.reminderMinute = Calendar.current.component(.minute, from: reminderTime)
        if oneOff && existing == nil && logOnSave {
            habit.record(HabitLog(occurredAt: firstLogTime, amount: Int(firstAmount) ?? 1))
        }
        if store.save(habit) {
            if reminder && !allowed { permissionDenied = true }
            else { dismiss() }
        }
        saving = false
    }

    private var firstLogRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: startDate)
        return start...max(start, min(Date(), Day.adding(1, to: start).addingTimeInterval(-1)))
    }
}
