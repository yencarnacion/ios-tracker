import SwiftUI
import HabitCore

struct LogEditor: View {
    @Environment(HabitStore.self) private var store
    let habitID: UUID
    var date: Date
    var existing: HabitLog?
    var body: some View {
        if store.habit(habitID)?.isNumeric == true {
            NumericLogEditor(habitID: habitID, date: date, existing: existing)
        } else { CounterLogEditor(habitID: habitID, date: date, existing: existing) }
    }
}

struct NumericLogEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    var date: Date
    var existing: HabitLog?
    @State private var timestamp = Date()
    @State private var inputs: [String: String] = [:]
    @State private var note = ""
    @State private var showDelete = false
    private var habit: Habit? { store.habit(habitID) }
    private var fields: [MetricField] {
        (habit?.metricFields ?? []).filter { !$0.archived || existing?.values?[$0.key] != nil }
    }
    private var parsed: [String: Double]? {
        var values: [String: Double] = [:]
        for field in fields {
            let text = (inputs[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            guard let value = NumericValue.parse(text) else { return nil }
            values[field.key] = value
        }
        return values.isEmpty ? nil : values
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                        HStack(spacing: 8) {
                            Text(field.label).frame(maxWidth: .infinity, alignment: .leading)
                            Button("±") {
                                let text = inputs[field.key] ?? ""
                                inputs[field.key] = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
                            }.buttonStyle(.borderless).accessibilityLabel("Toggle sign for \(field.name)")
                            TextField("Value", text: binding(field.key)).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).frame(minWidth: 70, maxWidth: 140)
                                .accessibilityLabel(field.label).accessibilityIdentifier("measurement-\(index)")
                            if !(inputs[field.key] ?? "").isEmpty {
                                Button { inputs[field.key] = "" } label: { Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(BloomStyle.secondary) }
                                    .buttonStyle(.borderless).accessibilityLabel("Clear \(field.name)")
                            }
                        }
                    }
                } header: { Text("\(habit?.emoji ?? "") \(habit?.title ?? "Values")") }
                footer: { Text("Enter at least one value. Leave a field empty if you didn’t measure it. Decimals, zero, and negative values are supported.") }
                Section {
                    DatePicker("When", selection: $timestamp, in: allowedRange,
                               displayedComponents: habit?.isOneOff == true ? [.hourAndMinute] : [.date, .hourAndMinute])
                        .accessibilityIdentifier("measurement-time")
                    TextField("Add a note (optional)", text: $note, axis: .vertical).lineLimit(3...6)
                        .accessibilityIdentifier("measurement-note")
                        .onChange(of: note) { _, value in note = String(value.prefix(5000)) }
                } footer: { Text("Every entry keeps its own timestamp and values, even when you log more than once in a day.") }
                if existing != nil { Section { Button("Delete entry", role: .destructive) { showDelete = true } } }
            }
            .navigationTitle(existing == nil ? "Record values" : "Edit values").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let values = parsed else { return }
                        let log = HabitLog(id: existing?.id ?? UUID(), occurredAt: timestamp, note: note, values: values)
                        if store.record(log, for: habitID) { dismiss() }
                    }.disabled(parsed == nil || timestamp > Date()).accessibilityIdentifier("save-entry")
                }
            }
            .onAppear {
                timestamp = existing?.occurredAt ?? min(Date(), Day.time(on: date, from: Date()))
                inputs = (existing?.values ?? [:]).mapValues { NumericValue.editText($0) }
                note = existing?.note ?? ""
            }
            .confirmationDialog("Delete this measurement entry?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Delete entry", role: .destructive) {
                    if let existing { store.deleteLog(existing.id, for: habitID) }; dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { inputs[key] ?? "" }, set: { inputs[key] = String($0.prefix(40)) })
    }
    private var allowedRange: ClosedRange<Date> {
        if let day = habit?.scheduledOnceDate {
            let start = Calendar.current.startOfDay(for: day)
            return start...max(start, min(Date(), Day.adding(1, to: start).addingTimeInterval(-1)))
        }
        let first = min(habit?.createdAt ?? date, existing?.occurredAt ?? date)
        return min(Calendar.current.startOfDay(for: first), Date())...Date()
    }
}
