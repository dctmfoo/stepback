import SwiftData
import SwiftUI

#if os(macOS)
struct PlayerWindowRoot: View {
    @Environment(\.dismiss) private var dismissWindow
    @Environment(PlayerPresentationStore.self) private var playerPresentation
    @Query private var routines: [Routine]

    var body: some View {
        Group {
            if let presentation = playerPresentation.presentation,
               let routine = routines.first(where: { $0.id == presentation.routine.id }) {
                PlayerStageRoot(
                    routine: routine,
                    planContext: presentation.planContext,
                    signposts: playerPresentation.signposts
                ) {
                    playerPresentation.dismiss()
                    dismissWindow()
                }
            } else {
                ContentUnavailableView(L10n.playerUnavailable, systemImage: "figure.run")
            }
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}
#endif
