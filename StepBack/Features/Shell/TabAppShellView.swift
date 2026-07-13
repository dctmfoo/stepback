import SwiftUI

struct TabAppShellView: View {
    @Environment(PlayerPresentationStore.self) private var playerPresentation
    @AppStorage(WelcomePreferences.seenKey) private var welcomeSeen = false
    @State private var selection = AppSection.routines
    @State private var welcomeIsPresented = WelcomePreferences.shouldPresent()

    var body: some View {
        #if os(iOS)
        @Bindable var playerPresentation = playerPresentation
        tabs
            .fullScreenCover(item: $playerPresentation.presentation) { presentation in
                PlayerStageRoot(
                    routine: presentation.routine,
                    planContext: presentation.planContext,
                    signposts: playerPresentation.signposts,
                    dismiss: playerPresentation.dismiss
                )
            }
            .fullScreenCover(isPresented: $welcomeIsPresented, onDismiss: markWelcomeSeen) {
                WelcomeView(getStarted: dismissWelcome)
            }
        #else
        tabs
        #endif
    }

    private func dismissWelcome() {
        welcomeSeen = true
        welcomeIsPresented = false
    }

    private func markWelcomeSeen() {
        welcomeSeen = true
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab(value: .routines) {
                RoutinesHomeView()
            } label: {
                Label(AppSection.routines.title, systemImage: AppSection.routines.systemImage)
                    .accessibilityIdentifier(AppSection.routines.accessibilityIdentifier)
            }

            Tab(value: .gallery) {
                GalleryView()
            } label: {
                Label(AppSection.gallery.title, systemImage: AppSection.gallery.systemImage)
                    .accessibilityIdentifier(AppSection.gallery.accessibilityIdentifier)
            }

            Tab(value: .settings) {
                SettingsView()
            } label: {
                Label(AppSection.settings.title, systemImage: AppSection.settings.systemImage)
                    .accessibilityIdentifier(AppSection.settings.accessibilityIdentifier)
            }
        }
        .tint(Color("PulseAzure"))
        .environment(\.playerLauncher, PlayerLauncher(action: playerPresentation.present))
    }
}
