import StepBackCore
import SwiftUI

struct RoutineCard: View {
    let routine: Routine
    let sessionSnapshots: [SessionSnapshot]
    let categoryIDs: [String]
    let open: () -> Void
    let play: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(routine.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(DisplayFormatters.duration(totalSeconds))
                        .font(.title2.bold())
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Text(L10n.workoutCount(stepCount))
                            RoutineCategoryDots(categoryIDs: categoryIDs)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.workoutCount(stepCount))
                            RoutineCategoryDots(categoryIDs: categoryIDs)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)

                    Text(statsLine)
                        .font(.footnote)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
            }
            .buttonStyle(.plain)

            Button(L10n.playRoutine(routine.name), systemImage: "play.fill", action: play)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(L10n.playRoutine(routine.name))
                .accessibilityIdentifier("home.card.play.\(routine.id)")
        }
        .padding(16)
        .background(PlatformColors.groupedSurface, in: .rect(cornerRadius: ShapeRadius.cardProminent))
        .accessibilityIdentifier("home.card.\(routine.id)")
        .contextMenu {
            Button(L10n.play, systemImage: "play.fill", action: play)
            Button(L10n.duplicate, systemImage: "plus.square.on.square", action: duplicate)
            Button(L10n.deleteRoutine, systemImage: "trash", role: .destructive, action: delete)
        }
    }

    private var stepCount: Int {
        routine.steps?.count ?? 0
    }

    private var totalSeconds: Int {
        TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
    }

    private var stats: PerRoutineStats {
        DerivedStats.perRoutine(sessions: sessionSnapshots, routineID: routine.id)
    }

    private var statsLine: String {
        guard let lastDone = stats.lastDone else { return L10n.notPlayedYet }
        return L10n.lastDone(
            DisplayFormatters.relativeDate(lastDone),
            timesCompleted: stats.timesCompleted
        )
    }

    private var accessibilitySummary: String {
        [
            routine.name,
            DisplayFormatters.spokenDuration(totalSeconds),
            L10n.workoutCount(stepCount),
            statsLine
        ].joined(separator: L10n.summarySeparator)
    }
}
