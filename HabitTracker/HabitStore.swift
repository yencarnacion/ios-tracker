import SwiftUI
import HabitCore
import UserNotifications

@MainActor @Observable
final class HabitStore {
    private(set) var document: HabitDocument
    var errorMessage: String?
    private let fileURL: URL
    private var canWrite = true
    private var reminderTask: Task<Void, Never>?

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let base = URL.applicationSupportDirectory.appending(path: "Bloom", directoryHint: .isDirectory)
        fileURL = base.appending(path: testing ? "ui-tests.json" : "habits.json")
        document = .starter()
        do {
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            if testing && ProcessInfo.processInfo.arguments.contains("--reset-data") { try? FileManager.default.removeItem(at: fileURL) }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                document = try HabitDocument.decode(Data(contentsOf: fileURL))
            } else {
                try persist(document)
            }
        } catch {
            document = HabitDocument()
            canWrite = false
            errorMessage = "Bloom couldn’t read your saved habits. Your original file has been kept. Restore a backup in Settings. \(error.localizedDescription)"
        }
    }

    var activeHabits: [Habit] { document.habits.filter { $0.archivedAt == nil } }
    var archivedHabits: [Habit] { document.habits.filter { $0.archivedAt != nil } }
    func habit(_ id: UUID) -> Habit? { document.habits.first { $0.id == id } }

    private func persist(_ value: HabitDocument) throws {
        try value.encoded().write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    @discardableResult
    private func update(_ change: (inout HabitDocument) -> Void) -> Bool {
        guard canWrite else {
            errorMessage = "Restore a valid backup in Settings before making changes. Your original file is safe."
            return false
        }
        var next = document
        change(&next)
        do { try persist(next); document = next; return true }
        catch { errorMessage = "Your change couldn’t be saved. \(error.localizedDescription)"; return false }
    }

    @discardableResult
    func save(_ habit: Habit) -> Bool {
        let saved = update { doc in
            if let index = doc.habits.firstIndex(where: { $0.id == habit.id }) { doc.habits[index] = habit }
            else { doc.habits.append(habit) }
        }
        if saved { refreshReminders() }
        return saved
    }

    func setCount(_ value: Int, for id: UUID, on date: Date) {
        guard Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()) else { return }
        if update({ doc in
            guard let index = doc.habits.firstIndex(where: { $0.id == id }) else { return }
            doc.habits[index].setCount(value, on: date)
        }) { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }

    func record(_ log: HabitLog, for id: UUID) {
        guard log.occurredAt <= Date(), (1...9999).contains(log.amount) else { return }
        if update({ doc in
            guard let index = doc.habits.firstIndex(where: { $0.id == id }) else { return }
            doc.habits[index].record(log)
        }) { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }

    func deleteLog(_ logID: UUID, for habitID: UUID) {
        _ = update { doc in
            guard let index = doc.habits.firstIndex(where: { $0.id == habitID }) else { return }
            doc.habits[index].removeLog(logID)
        }
    }

    func completeAll(on date: Date) {
        guard Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()) else { return }
        _ = update { doc in
            for index in doc.habits.indices where doc.habits[index].archivedAt == nil && doc.habits[index].isScheduled(on: date) && !doc.habits[index].isComplete(on: date) {
                doc.habits[index].setCount(doc.habits[index].target, on: date)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func setNote(_ note: String, for id: UUID, on date: Date) {
        _ = update { doc in
            guard let index = doc.habits.firstIndex(where: { $0.id == id }) else { return }
            doc.habits[index].setNote(String(note.prefix(5000)), on: date)
        }
    }

    func setMood(_ mood: String, on date: Date) {
        _ = update { $0.moods[Day.key(date)] = mood }
    }

    func archive(_ id: UUID) {
        guard var h = habit(id) else { return }
        h.archivedAt = Date()
        save(h)
    }

    func restore(_ id: UUID) {
        guard var h = habit(id) else { return }
        h.archivedAt = nil
        save(h)
    }

    func move(_ id: UUID, by offset: Int) {
        _ = update { doc in
            guard let index = doc.habits.firstIndex(where: { $0.id == id }) else { return }
            let other = index + offset
            guard doc.habits.indices.contains(other) else { return }
            doc.habits.swapAt(index, other)
        }
    }

    func reorderActive(_ ids: [UUID]) {
        _ = update { doc in
            let active = ids.compactMap { id in doc.habits.first { $0.id == id && $0.archivedAt == nil } }
            doc.habits = active + doc.habits.filter { $0.archivedAt != nil }
        }
    }

    func backupURL() -> URL? {
        let url = URL.temporaryDirectory.appending(path: "Bloom-backup-\(Day.key(Date())).json")
        do { try document.encoded().write(to: url, options: .atomic); return url }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    func importBackup(_ data: Data) throws {
        let next = try HabitDocument.decode(data)
        try persist(next)
        canWrite = true
        document = next
        refreshReminders()
    }

    func refreshReminders() {
        let habits = activeHabits
        let previous = reminderTask
        reminderTask = Task {
            await previous?.value
            await ReminderScheduler.reschedule(habits)
        }
    }
}

actor ReminderScheduler {
    static func requestAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        center.removeAllPendingNotificationRequests()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        // iOS allows 64 pending notifications; eight habits fit even with seven weekly triggers each.
        for habit in habits.filter({ $0.reminderHour != nil && $0.oneOffDate == nil }).prefix(8) {
            guard let hour = habit.reminderHour else { continue }
            let weekdays: [Int?] = habit.weekdays.count == 7 ? [nil] : habit.weekdays.sorted().map { Optional($0) }
            for weekday in weekdays {
                var components = DateComponents()
                components.hour = hour; components.minute = habit.reminderMinute; components.weekday = weekday
                let content = UNMutableNotificationContent()
                content.title = "\(habit.emoji) \(habit.title)"
                content.body = "A little progress goes a long way. Your habit is ready."
                content.sound = .default
                let id = "\(habit.id)-\(weekday ?? 0)"
                try? await center.add(UNNotificationRequest(identifier: id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            }
        }
    }
}
