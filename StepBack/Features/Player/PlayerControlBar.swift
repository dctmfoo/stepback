import SwiftUI

struct PlayerControlBar: View {
    let model: PlayerSessionModel
    let end: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            control(L10n.playerBack, systemImage: "backward.end.fill", action: model.back)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityIdentifier("player.back")

            Button(
                model.isPaused ? L10n.playerResume : L10n.playerPause,
                systemImage: model.isPaused ? "play.fill" : "pause.fill",
                action: model.togglePause
            )
            .labelStyle(.iconOnly)
            .frame(width: 72, height: 72)
            .background(PlayerStageColors.accent(for: model.currentSegment?.kind), in: .circle)
            .foregroundStyle(Color("StageCanvas"))
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(model.isPaused ? L10n.playerResume : L10n.playerPause)
            .accessibilityIdentifier("player.playPause")

            control(L10n.playerSkip, systemImage: "forward.end.fill", action: model.skip)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityIdentifier("player.skip")

            Button(L10n.playerEnd, action: end)
                .frame(minWidth: 64, minHeight: 64)
                .foregroundStyle(Color("StageTextDim"))
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityIdentifier("player.end")
        }
        .padding(8)
        .background(Color("StageSurface").opacity(0.92), in: .capsule)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay {
            Capsule()
                .stroke(Color("StageText").opacity(0.08), lineWidth: 1)
        }
    }

    private func control(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(label, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .frame(width: 64, height: 64)
            .background(Color("StageText").opacity(0.08), in: .circle)
            .foregroundStyle(Color("StageText"))
            .accessibilityLabel(label)
    }
}
