import SwiftUI
import HabitCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(HabitStore.self) private var store
    @State private var importing = false
    @State private var pendingImport: Data?
    @State private var confirmImport = false
    @State private var sharedFile: SharedFile?
    @State private var importError: String?
    @State private var showHabits = false
    @State private var showArchive = false
    @State private var showTimeline = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 15) {
                        Text("🌷").font(.system(size: 42)).frame(width: 70, height: 70)
                            .background(BloomStyle.pinkTrack.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Bloom").font(.system(size: 27, weight: .bold, design: .rounded))
                            Text("Little steps, every day.").font(.subheadline).foregroundStyle(BloomStyle.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("Your little routines") {
                    Button { showHabits = true } label: { settingsRow("Manage items", symbol: "slider.horizontal.3", color: BloomStyle.coral, trailing: "\(store.activeHabits.count)") }
                    Button { showArchive = true } label: { settingsRow("Archived items", symbol: "archivebox", color: .orange, trailing: "\(store.archivedHabits.count)") }
                    Button { showTimeline = true } label: { settingsRow("All activity", symbol: "clock", color: .purple) }
                }
                Section {
                    Button {
                        if let url = store.backupURL() { sharedFile = SharedFile(url: url) }
                    } label: { settingsRow("Export backup", symbol: "square.and.arrow.up", color: BloomStyle.mint) }
                    Button { importing = true } label: { settingsRow("Restore backup", symbol: "square.and.arrow.down", color: .blue) }
                    Button { exportCSV() } label: { settingsRow("Export check-ins as CSV", symbol: "tablecells", color: .purple) }
                } header: { Text("Your data") } footer: {
                    Text("Habits, one-off items, exact timestamps, notes, and moods are stored on this iPhone. Export a backup to keep a copy or move to another device. CSV includes a row for every check-in.")
                }
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: { settingsRow("Notification settings", symbol: "bell", color: .orange) }
                } footer: { Text("Reminders are optional and scheduled locally. Manage each habit’s reminder in its editor.") }
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    Link(destination: URL(string: "https://github.com/yencarnacion/ios-tracker")!) {
                        settingsRow("Source code", symbol: "chevron.left.forwardslash.chevron.right", color: BloomStyle.secondary)
                    }
                } footer: { Text("Made for a calmer kind of consistency. No account, subscription, ads, or analytics.").multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 12) }
            }.navigationTitle("Settings").listStyle(.insetGrouped)
                .sheet(isPresented: $showHabits) { ManageHabitsView(archived: false) }
                .sheet(isPresented: $showArchive) { ManageHabitsView(archived: true) }
                .sheet(isPresented: $showTimeline) { ActivityView() }
                .sheet(item: $sharedFile) { ActivityShareSheet(items: [$0.url]) }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                    do {
                        let url = try result.get()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        _ = try HabitDocument.decode(data)
                        pendingImport = data; confirmImport = true
                    } catch { importError = error.localizedDescription }
                }
                .confirmationDialog("Replace your current data with this backup? Export a backup first if you want to keep your current data.", isPresented: $confirmImport, titleVisibility: .visible) {
                    Button("Replace with backup", role: .destructive) {
                        do { if let pendingImport { try store.importBackup(pendingImport) } }
                        catch { importError = error.localizedDescription }
                        pendingImport = nil
                    }
                    Button("Cancel", role: .cancel) { pendingImport = nil }
                }
                .alert("Couldn’t open this backup", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                    Button("OK") { importError = nil }
                } message: { Text(importError ?? "") }
        }
    }

    private func settingsRow(_ title: String, symbol: String, color: Color, trailing: String = "") -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color)
                .frame(width: 29, height: 33)
            Text(title).foregroundStyle(BloomStyle.ink)
            Spacer()
            if !trailing.isEmpty { Text(trailing).foregroundStyle(BloomStyle.secondary).font(.subheadline) }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(BloomStyle.secondary)
        }.padding(.vertical, 3)
    }

    private func exportCSV() {
        func cell(_ value: String) -> String {
            // Prevent spreadsheet formula interpretation of user-entered text.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: value.hasPrefix) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var rows = [["Item", "Type", "Local date", "Local time", "Timestamp (UTC)", "Amount", "Unit", "Note"]]
        let pairs = store.document.habits.flatMap { habit in habit.allLogs.map { (habit, $0) } }
            .sorted { $0.1.occurredAt < $1.1.occurredAt }
        for (habit, log) in pairs {
            rows.append([habit.title, habit.oneOffDate == nil ? "Habit" : "One-off", Day.key(log.occurredAt),
                         log.occurredAt.formatted(date: .omitted, time: .standard), log.occurredAt.ISO8601Format(),
                         String(log.amount), habit.unit, log.note])
        }
        let csv = rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n")
        let url = URL.temporaryDirectory.appending(path: "Bloom-check-ins.csv")
        do { try Data(csv.utf8).write(to: url, options: .atomic); sharedFile = SharedFile(url: url) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

struct ManageHabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let archived: Bool
    @State private var editing: Habit?
    @State private var adding = false
    var habits: [Habit] { archived ? store.archivedHabits : store.activeHabits }
    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty { ContentUnavailableView(archived ? "No archived items" : "Room to grow", systemImage: "leaf") }
                ForEach(habits) { habit in
                    HStack {
                        Text(habit.emoji).font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.title)
                            Text(habit.oneOffDate.map { "One-off · \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "\(habit.target) \(habit.unit) · \(habit.weekdays.count == 7 ? "Every day" : "\(habit.weekdays.count) days a week")")
                                .font(.caption).foregroundStyle(BloomStyle.secondary)
                        }
                        Spacer()
                        if archived { Button("Restore") { store.restore(habit.id) }.font(.subheadline) }
                        else { Button { editing = habit } label: { Image(systemName: "pencil") }.accessibilityLabel("Edit \(habit.title)") }
                    }.padding(.vertical, 5)
                        .swipeActions {
                            if !archived { Button("Archive", systemImage: "archivebox") { store.archive(habit.id) }.tint(.orange) }
                        }
                }.onMove { from, to in
                    guard !archived else { return }
                    var active = store.activeHabits
                    active.move(fromOffsets: from, toOffset: to)
                    store.reorderActive(active.map(\.id))
                }
            }
            .navigationTitle(archived ? "Archived items" : "Manage items").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if !archived {
                    ToolbarItem(placement: .primaryAction) {
                        HStack { EditButton(); Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add an item") }
                    }
                }
            }
            .sheet(item: $editing) { HabitEditor(existing: $0) }
            .sheet(isPresented: $adding) { HabitEditor() }
        }
    }
}

struct SharedFile: Identifiable { let id = UUID(); let url: URL }

struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
