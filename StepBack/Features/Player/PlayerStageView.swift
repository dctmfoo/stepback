import StepBackCore
import SwiftUI

struct PlayerStageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: PlayerSessionModel
    let workout: WorkoutItem?
    let categoryName: String?
    let end: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.15
            VStack(spacing: 16) {
                stageHeader
                PlayerSegmentView(
                    model: model,
                    workout: workout,
                    categoryName: categoryName,
                    isWide: isWide,
                    countdownSize: countdownSize(for: proxy.size, isWide: isWide)
                )
                PlayerProgressFoot(model: model)
                PlayerControlBar(model: model, end: end)
            }
            .padding(isWide ? 24 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(
                reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.28, bounce: 0),
                value: model.snapshot.currentSegmentIndex
            )
        }
        .foregroundStyle(Color("StageText"))
    }

    private var stageHeader: some View {
        Text(model.routineName)
            .font(.headline)
            .foregroundStyle(Color("StageTextDim"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countdownSize(for size: CGSize, isWide: Bool) -> CGFloat {
        let proportion = isWide ? size.height * 0.27 : size.height * 0.17
        return min(220, max(72, proportion))
    }
}
