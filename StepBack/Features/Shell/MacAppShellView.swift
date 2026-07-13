import SwiftData
import SwiftUI

#if os(macOS)
struct MacAppShellView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(PlayerPresentationStore.self) private var playerPresentation
    @Query private var routines: [Routine]
    @AppStorage(WelcomePreferences.seenKey) private var welcomeSeen = false
    @State private var detailRoute: MacDetailRoute?
    @State private var selection = AppSection.routines
    @State private var welcomeIsPresented = WelcomePreferences.shouldPresent()

    var body: some View {
        Group {
            if selection == .settings {
                NavigationSplitView {
                    MacSidebar(selection: $selection)
                } detail: {
                    SettingsView()
                }
            } else {
                NavigationSplitView {
                    MacSidebar(selection: $selection)
                } content: {
                    MacSectionContent(section: selection) { route in
                        detailRoute = route
                    }
                } detail: {
                    detailContent
                }
            }
        }
        .onChange(of: selection) { _, _ in
            detailRoute = nil
        }
        .tint(Color("PulseAzure"))
        .environment(\.playerLauncher, PlayerLauncher { routine, planContext in
            playerPresentation.present(routine, planContext: planContext)
            openWindow(id: "player")
        })
        .sheet(isPresented: $welcomeIsPresented, onDismiss: markWelcomeSeen) {
            WelcomeView(getStarted: dismissWelcome)
                .frame(minWidth: 520, minHeight: 620)
        }
    }

    private func dismissWelcome() {
        welcomeSeen = true
        welcomeIsPresented = false
    }

    private func markWelcomeSeen() {
        welcomeSeen = true
    }

    @ViewBuilder
    private var detailContent: some View {
        switch detailRoute {
        case let .routine(id):
            if let routine = routines.first(where: { $0.id == id }) {
                RoutineDetailView(routine: routine)
            } else {
                detailPlaceholder
            }
        case let .workout(item):
            WorkoutDetailView(
                item: item,
                onCreatedRoutine: { detailRoute = .routine($0) },
                onDeleted: { detailRoute = nil }
            )
        case nil:
            detailPlaceholder
        }
    }

    private var detailPlaceholder: some View {
        ContentUnavailableView(
            selection == .gallery ? L10n.selectedWorkoutPrompt : L10n.selectedRoutinePrompt,
            systemImage: selection.systemImage
        )
    }
}
#endif
