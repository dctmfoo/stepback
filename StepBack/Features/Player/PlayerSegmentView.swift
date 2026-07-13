import StepBackCore
import SwiftUI

struct PlayerSegmentView: View {
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
                VStack(spacing: 24) {
                    segmentText
                    visual
                        .frame(
                            maxWidth: stackedVisualHeight * 4 / 3,
                            idealHeight: stackedVisualHeight,
                            maxHeight: stackedVisualHeight
                        )
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(model.snapshot.currentSegmentIndex)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var segmentText: some View {
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
                    .accessibilityIdentifier("player.next")
                countdown
                supportingText
            } else {
                countdown
                Text(headline)
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("player.name")
                supportingText
            }
        }
        .multilineTextAlignment(isWide ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: isWide ? .leading : .center)
    }

    @ViewBuilder
    private var supportingText: some View {
        if let detail, isWide || !showsNextLine {
            Text(detail)
                .font(.title3)
                .foregroundStyle(Color("StageTextDim"))
                .accessibilityIdentifier("player.setIndicator")
        }
        if showsNextLine,
           let next = model.currentSegment?.nextWorkoutNameSnapshot {
            Text(L10n.playerNext(next))
                .font(.headline)
                .foregroundStyle(Color("StageTextDim"))
                .accessibilityIdentifier("player.next")
        }
    }

    private var countdown: some View {
        Text(DisplayFormatters.stageDuration(displayedSeconds))
            .font(.system(size: countdownSize, weight: .heavy, design: .rounded))
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
        !leadsWithNext
            && model.showsNextDuringWork
            && model.currentSegment?.nextWorkoutNameSnapshot != nil
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
