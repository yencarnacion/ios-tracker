import SwiftUI

@main
struct BloomApp: App {
    @State private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(BloomStyle.coral)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshReminders() }
                }
        }
    }
}

enum BloomTab: String, CaseIterable {
    case today = "Today", progress = "Progress", report = "Report", settings = "Settings"
    var icon: String {
        switch self {
        case .today: "house.fill"
        case .progress: "chart.bar.xaxis"
        case .report: "list.clipboard.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct RootView: View {
    @Environment(HabitStore.self) private var store
    @State private var tab: BloomTab = .today
    @State private var addingHabit = false
    var body: some View {
        @Bindable var store = store
        ZStack {
            BloomStyle.canvas.ignoresSafeArea()
            switch tab {
            case .today: TodayView()
            case .progress: StatisticsView()
            case .report: ReportView()
            case .settings: SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 2) {
                tabButton(.today)
                tabButton(.progress)
                Button { addingHabit = true } label: {
                    Image(systemName: "plus").font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white).frame(width: 48, height: 48)
                        .background(BloomStyle.coral, in: Circle())
                }.frame(maxWidth: .infinity).accessibilityLabel("Add habit")
                tabButton(.report)
                tabButton(.settings)
            }
            .padding(7).background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.08)))
            .padding(.horizontal, 20).padding(.top, 9).padding(.bottom, 6)
        }
        .sheet(isPresented: $addingHabit) { HabitEditor() }
        .alert("Something needs attention", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private func tabButton(_ value: BloomTab) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 3) {
                Image(systemName: value.icon).font(.system(size: 21, weight: .semibold))
                Text(value.rawValue).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(tab == value ? BloomStyle.coral : BloomStyle.ink.opacity(0.7))
            .frame(maxWidth: .infinity).frame(height: 49)
            .background(tab == value ? Color.black.opacity(0.055) : .clear, in: Capsule())
        }.accessibilityLabel(value.rawValue + " tab")
            .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}
