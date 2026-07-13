import SwiftUI

struct PlayerProgressFoot: View {
    let model: PlayerSessionModel

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: model.progress)
                .tint(PlayerStageColors.accent(for: model.currentSegment?.kind))
                .scaleEffect(y: 2)
                .accessibilityHidden(true)
            HStack {
                Text(DisplayFormatters.stageDuration(model.elapsedRoutineSeconds))
                    .accessibilityIdentifier("player.elapsed")
                Spacer()
                Text(DisplayFormatters.stageDuration(model.remainingRoutineSeconds))
                    .accessibilityIdentifier("player.remaining")
            }
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(Color("StageTextDim"))
        }
        .foregroundStyle(Color("StageText"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.playerProgress)
        .accessibilityValue(L10n.playerProgressValue(
            DisplayFormatters.spokenDuration(model.elapsedRoutineSeconds),
            remaining: DisplayFormatters.spokenDuration(model.remainingRoutineSeconds)
        ))
        .accessibilityIdentifier("player.progress")
    }
}
