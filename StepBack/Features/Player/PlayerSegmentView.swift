import StepBackCore
import SwiftUI

struct PlayerSegmentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: PlayerSessionModel
    let workout: WorkoutItem?
    let categoryName: String?
    let isWide: Bool
    let countdownSize: CGFloat
    let stackedVisualHeight: CGFloat

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 40) {
                    segmentText
                    visual
                        .frame(maxWidth: 360)
                }
            } else {
                PlayerStackedSegmentLayout(visualHeight: stackedVisualHeight) {
                    segmentText
                    visual
                        .frame(
                            maxWidth: stackedVisualHeight * 4 / 3,
                            idealHeight: stackedVisualHeight,
                            maxHeight: stackedVisualHeight
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(model.snapshot.currentSegmentIndex)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    @ViewBuilder
    private var segmentText: some View {
        if isWide {
            segmentText(countdownSize: countdownSize)
        } else {
            segmentText(
                countdownSize: dynamicTypeSize.isAccessibilitySize ? 44 : countdownSize
            )
        }
    }

    private func segmentText(countdownSize: CGFloat) -> some View {
        VStack(alignment: isWide ? .leading : .center, spacing: 8) {
            Text(kicker)
                .font(.headline.bold())
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(PlayerStageColors.accent(for: model.currentSegment?.kind))
                .accessibilityIdentifier("player.kicker")

            if leadsWithNext {
                Text(headline)
                    .font(.largeTitle.bold())
                    .lineLimit(isWide ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("player.next")
                countdown(size: countdownSize)
                supportingText
            } else {
                countdown(size: countdownSize)
                Text(headline)
                    .font(.largeTitle.bold())
                    .lineLimit(isWide ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("player.name")
                supportingText
            }
        }
        .multilineTextAlignment(isWide ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: isWide ? .leading : .center)
    }

    @ViewBuilder
    private var supportingText: some View {
        if let detail {
            Text(detail)
                .font(.title3)
                .foregroundStyle(Color("StageTextDim"))
                .accessibilityIdentifier("player.setIndicator")
        }
        if let workNextName {
            workNextUp(workNextName)
        }
    }

    @ViewBuilder
    private func workNextUp(_ next: String) -> some View {
        if isWide {
            if showsNextLine {
                nextUpText(next)
            }
        } else {
            nextUpText(
                next,
                accessibilityIdentifier: showsNextLine ? "player.next" : ""
            )
                .opacity(showsNextLine ? 1 : 0)
                .accessibilityHidden(!showsNextLine)
                .animation(.easeInOut(duration: 0.2), value: showsNextLine)
        }
    }

    private func nextUpText(
        _ next: String,
        accessibilityIdentifier: String = "player.next"
    ) -> some View {
        Text(L10n.playerNext(next))
            .font(.headline)
            .lineLimit(isWide ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color("StageTextDim"))
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func countdown(size: CGFloat) -> some View {
        Text(DisplayFormatters.stageDuration(displayedSeconds))
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .accessibilityLabel(L10n.playerTimeRemaining)
            .accessibilityValue(DisplayFormatters.spokenDuration(displayedSeconds))
            .accessibilityIdentifier("player.countdown")
    }

    @ViewBuilder
    private var visual: some View {
        if let workout {
            WorkoutVisual(workout: workout, categoryName: categoryName, variant: .stage)
        } else if let step = model.currentSegment?.step {
            WorkoutVisual(
                workoutID: step.workoutID,
                categoryID: nil,
                categoryName: nil,
                variant: .stage
            )
        }
    }

    private var displayedSeconds: Int {
        model.resumeCountdownRemaining ?? model.snapshot.remainingSeconds
    }

    private var leadsWithNext: Bool {
        guard let kind = model.currentSegment?.kind else { return false }
        return kind == .getReady || kind == .rest || kind == .setRest
    }

    private var showsNextLine: Bool {
        workNextName != nil && model.showsNextDuringWork
    }

    private var workNextName: String? {
        guard !leadsWithNext else { return nil }
        return model.currentSegment?.nextWorkoutNameSnapshot
    }

    private var kicker: String {
        guard let segment = model.currentSegment else { return L10n.playerKickerWork }
        switch segment.kind {
        case .getReady:
            return L10n.playerKickerGetReady
        case .work:
            if let setIndex = segment.setIndex, let setCount = segment.setCount, setCount > 1 {
                return [L10n.playerKickerWork, L10n.playerSetIndicator(setIndex, setCount: setCount)]
                    .joined(separator: L10n.kickerSeparator)
            }
            return L10n.playerKickerWork
        case .setRest, .rest:
            return L10n.playerKickerRest
        }
    }

    private var headline: String {
        guard let segment = model.currentSegment else { return model.routineName }
        switch segment.kind {
        case .getReady:
            return L10n.playerFirst(segment.step?.workoutNameSnapshot ?? model.routineName)
        case .setRest:
            return L10n.playerNext(segment.step?.workoutNameSnapshot ?? model.routineName)
        case .rest:
            return L10n.playerNext(segment.nextWorkoutNameSnapshot ?? model.routineName)
        case .work:
            return segment.step?.workoutNameSnapshot ?? model.routineName
        }
    }

    private var detail: String? {
        guard let segment = model.currentSegment else { return nil }
        switch segment.kind {
        case .getReady, .setRest, .rest:
            return L10n.playerWorkoutIndicator(model.workoutIndex, count: model.workoutCount)
        case .work:
            if let reps = segment.repGuidance {
                return [
                    L10n.playerWorkoutIndicator(model.workoutIndex, count: model.workoutCount),
                    L10n.reps(reps)
                ].joined(separator: L10n.summarySeparator)
            }
            return L10n.playerWorkoutIndicator(model.workoutIndex, count: model.workoutCount)
        }
    }
}
