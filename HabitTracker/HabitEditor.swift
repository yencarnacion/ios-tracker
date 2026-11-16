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
    @State private var kind: ScheduleKind = .weekdays
    @State private var weekdays = Set(1...7)
    @State private var intervalDays = "2"
    @State private var monthlyDay = 1
    @State private var annualMonth = 1
    @State private var annualDay = 1
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
    private var schedule: TaskSchedule {
        switch kind {
        case .weekdays: .weekdays(weekdays)
        case .interval: .interval(days: Int(intervalDays) ?? 0)
        case .monthly: .monthly(day: monthlyDay)
        case .yearly: .yearly(month: annualMonth, day: annualDay)
        case .once: .once(Calendar.current.startOfDay(for: startDate))
        }
    }
    private var future: Bool { Calendar.current.startOfDay(for: startDate) > Calendar.current.startOfDay(for: Date()) }
    private var recordsFirstEntry: Bool { kind == .once && existing == nil && !future && logOnSave }
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !emoji.isEmpty && schedule.isValid &&
        (!recordsFirstEntry || ((1...9999).contains(Int(firstAmount) ?? 0) && firstLogTime <= Date()))
    }
    private var dateRange: ClosedRange<Date> {
        let upper = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Day.adding(730, to: Date())
        return Date(timeIntervalSince1970: 0)...max(upper, existing?.createdAt ?? upper, existing?.oneOffDate ?? upper)
    }
    private var annualDayCount: Int {
        let date = Calendar.current.date(from: DateComponents(year: 2000, month: annualMonth, day: 1)) ?? Date()
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    var body: some View {
        NavigationStack {
            Form {
                scheduleSection
                appearanceSection
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
                    Stepper("Goal on each due day: \(target)", value: $target, in: 1...9999)
                    HStack {
                        Text("Unit")
                        TextField("times, min, pages…", text: $unit).multilineTextAlignment(.trailing)
                            .onChange(of: unit) { _, new in unit = String(new.prefix(20)) }
                    }
                } header: { Text("A small, doable goal") } footer: { Text("Leave the unit empty for a simple check-in.") }
                Section {
                    Toggle("Gentle reminder", isOn: $reminder)
                        .disabled(existing?.reminderHour == nil && store.activeHabits.filter { $0.reminderHour != nil }.count >= 8)
                    if reminder { DatePicker("At", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                } footer: { Text("Optional reminders follow this schedule. Up to eight items can have reminders.") }
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
            .onAppear(perform: load)
            .onChange(of: startDate) { _, day in firstLogTime = min(Date(), Day.time(on: day, from: firstLogTime)) }
            .onChange(of: annualMonth) { _, _ in annualDay = min(annualDay, annualDayCount) }
            .alert("Reminders are off", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    dismiss()
                }
                Button("Keep item without reminder") { dismiss() }
            } message: { Text("Your item was saved. Enable notifications for ios-tracker in iPhone Settings, then turn its reminder on again.") }
        }
    }

    private var scheduleSection: some View {
        Section {
            Menu {
                ForEach(ScheduleKind.allCases) { option in
                    Button { kind = option } label: {
                        if kind == option { Label(option.title, systemImage: "checkmark") }
                        else { Text(option.title) }
                    }
                }
            } label: {
                HStack {
                    Text("Repeat").foregroundStyle(BloomStyle.ink)
                    Spacer()
                    Text(kind.title)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }.accessibilityIdentifier("schedule-type")
            switch kind {
            case .weekdays: weekdayControls
            case .interval:
                HStack {
                    Text("Every")
                    TextField("Days", text: $intervalDays).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("interval-days")
                        .onChange(of: intervalDays) { _, value in intervalDays = String(value.filter(\.isNumber).prefix(3)) }
                    Text("days").foregroundStyle(BloomStyle.secondary)
                }
                if !schedule.isValid { Text("Enter 1–730 days.").foregroundStyle(.red).font(.caption) }
            case .monthly:
                Picker("Day of month", selection: $monthlyDay) {
                    ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                }.accessibilityIdentifier("monthly-day")
            case .yearly:
                Picker("Month", selection: $annualMonth) {
                    ForEach(1...12, id: \.self) { Text(Calendar.current.monthSymbols[$0 - 1]).tag($0) }
                }.accessibilityIdentifier("annual-month")
                Picker("Day", selection: $annualDay) {
                    ForEach(1...annualDayCount, id: \.self) { Text("\($0)").tag($0) }
                }.accessibilityIdentifier("annual-day")
            case .once: EmptyView()
            }
            DatePicker(kind == .once ? "Due date" : kind == .interval ? "First due date" : "Starts on",
                       selection: $startDate, in: dateRange, displayedComponents: .date)
                .accessibilityIdentifier("task-date")
                .disabled(kind == .once && existing?.isOneOff == true && existing?.allLogs.isEmpty == false)
            if !(kind == .once && existing?.isOneOff == true && existing?.allLogs.isEmpty == false) {
                HStack(spacing: 16) {
                    Button("Today") { startDate = Date() }.accessibilityIdentifier("due-today")
                    Button("Tomorrow") { startDate = Day.adding(1, to: Date()) }.accessibilityIdentifier("due-tomorrow")
                    Button("In a week") { startDate = Day.adding(7, to: Date()) }
                }.font(.system(size: 13, weight: .medium)).buttonStyle(.borderless)
            }
            if kind == .once && existing == nil && !future {
                Toggle("Record first check-in", isOn: $logOnSave)
                if logOnSave {
                    DatePicker("Time", selection: $firstLogTime, in: firstLogRange, displayedComponents: .hourAndMinute)
                    HStack {
                        Text("Amount")
                        TextField("1", text: $firstAmount).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }
            }
            if schedule.isValid {
                let next = schedule.occurrences(onOrAfter: Date(), starting: startDate, count: 3)
                if !next.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Next due dates").font(.caption.weight(.semibold)).foregroundStyle(BloomStyle.secondary)
                        ForEach(next, id: \.self) { date in
                            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
                                .font(.system(size: 13)).foregroundStyle(BloomStyle.ink)
                        }
                    }.padding(.vertical, 3).accessibilityIdentifier("schedule-preview")
                }
            }
        } header: { Text("Schedule") } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(scheduleExplanation)
                if existing != nil { Text("Schedule or goal changes recalculate past goal statistics. Recorded check-ins stay in your timeline.") }
            }
        }
    }

    private var weekdayControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(Array(weekValues.enumerated()), id: \.offset) { index, value in
                    Button {
                        if weekdays.contains(value) { weekdays.remove(value) } else { weekdays.insert(value) }
                    } label: {
                        Text(weekLabels[index]).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(weekdays.contains(value) ? .white : BloomStyle.secondary)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(weekdays.contains(value) ? BloomStyle.coral : BloomStyle.canvas, in: Circle())
                            .padding(.horizontal, 2)
                    }.buttonStyle(.plain).accessibilityLabel(Calendar.current.weekdaySymbols[value - 1])
                        .accessibilityAddTraits(weekdays.contains(value) ? .isSelected : [])
                }
            }
            HStack(spacing: 15) {
                Button("Every day") { weekdays = Set(1...7) }
                Button("Mon–Fri") { weekdays = [2, 3, 4, 5, 6] }.accessibilityIdentifier("preset-weekdays")
                Button("Saturdays") { weekdays = [7] }.accessibilityIdentifier("preset-saturdays")
                Spacer(minLength: 0)
            }.font(.system(size: 12, weight: .medium)).buttonStyle(.borderless)
            if weekdays.isEmpty { Text("Choose at least one day.").foregroundStyle(.red).font(.caption) }
        }.padding(.vertical, 6)
    }

    private var appearanceSection: some View {
        Section {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 33)).frame(width: 58, height: 58)
                    .background(tint.background, in: RoundedRectangle(cornerRadius: 15))
                TextField("Task name", text: $title).font(.system(size: 20, weight: .medium))
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
    }

    private var scheduleExplanation: String {
        switch kind {
        case .weekdays: return "Due only on the weekdays you select, beginning on the start date."
        case .interval: return "Repeat every 1–730 days (up to two years), counted from the first due date. Completing it late does not move the schedule."
        case .monthly: return "Due every month on day \(monthlyDay). If that day is missing in a shorter month, use its last day."
        case .yearly: return annualMonth == 2 && annualDay == 29 ? "February 29 repeats in leap years only." : "Repeats on this month and day every year."
        case .once: return future ? "Scheduled once for this future date. Check-ins become available when the day arrives." : "A one-off stays in this day’s history and never repeats. You can log it more than once."
        }
    }

    private func load() {
        startDate = initialDate
        firstLogTime = min(Date(), Day.time(on: initialDate, from: Date()))
        kind = initialOneOff ? .once : .weekdays
        monthlyDay = Calendar.current.component(.day, from: initialDate)
        annualMonth = Calendar.current.component(.month, from: initialDate)
        annualDay = monthlyDay
        guard let h = existing else { return }
        title = h.title; emoji = h.emoji; tint = h.tint; target = h.target; unit = h.unit
        startDate = h.createdAt; reminder = h.reminderHour != nil
        kind = h.effectiveSchedule.kind
        switch h.effectiveSchedule {
        case .weekdays(let days): weekdays = days
        case .interval(let days): intervalDays = String(days)
        case .monthly(let day): monthlyDay = day
        case .yearly(let month, let day): annualMonth = month; annualDay = day
        case .once(let day): startDate = day
        }
        reminderTime = Calendar.current.date(from: DateComponents(hour: h.reminderHour ?? 9, minute: h.reminderMinute)) ?? Date()
    }

    private func save() async {
        saving = true
        let allowed = reminder ? await ReminderScheduler.requestAccess() : false
        var habit = existing ?? Habit(title: title)
        habit.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.emoji = emoji; habit.tint = tint; habit.target = target
        habit.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        habit.weekdays = kind == .weekdays ? weekdays : Set(1...7)
        habit.createdAt = Calendar.current.startOfDay(for: startDate)
        habit.oneOffDate = kind == .once ? Calendar.current.startOfDay(for: startDate) : nil
        habit.schedule = schedule
        habit.reminderHour = reminder && allowed ? Calendar.current.component(.hour, from: reminderTime) : nil
        habit.reminderMinute = Calendar.current.component(.minute, from: reminderTime)
        if recordsFirstEntry { habit.record(HabitLog(occurredAt: firstLogTime, amount: Int(firstAmount) ?? 1)) }
        if store.save(habit) {
            if reminder && !allowed { permissionDenied = true } else { dismiss() }
        }
        saving = false
    }

    private var firstLogRange: ClosedRange<Date> {
        let start = Calendar.current.startOfDay(for: startDate)
        return start...max(start, min(Date(), Day.adding(1, to: start).addingTimeInterval(-1)))
    }
}
