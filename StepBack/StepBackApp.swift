import SwiftUI
import SwiftData

@main
struct StepBackApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let bootstrap: StepBackBootstrap
    @State private var playerPresentation = PlayerPresentationStore()

    init() {
        do {
            bootstrap = try StepBackBootstrap()
        } catch {
            fatalError("StepBack failed to load its persistence stack: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .modifier(AccessibilityTestDynamicTypeModifier())
                .environment(bootstrap.catalogService)
                .environment(playerPresentation)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        bootstrap.reconcileStarterRoutines()
                    }
                }
        }
        .modelContainer(bootstrap.modelContainer)

        #if os(macOS)
        Window(L10n.playerWindowTitle, id: "player") {
            PlayerWindowRoot()
                .environment(bootstrap.catalogService)
                .environment(playerPresentation)
        }
        .modelContainer(bootstrap.modelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        #endif
    }
}

private struct AccessibilityTestDynamicTypeModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-StepBackUITesting"),
           ProcessInfo.processInfo.environment["StepBackUIAccessibilityXXXL"] == "1" {
            content.environment(\.dynamicTypeSize, .accessibility5)
        } else {
            content
        }
    }
}
