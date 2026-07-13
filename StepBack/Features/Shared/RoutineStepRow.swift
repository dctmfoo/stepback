import SwiftUI

struct RoutineStepRow: View {
    let step: RoutineStep
    let index: Int
    let workout: WorkoutItem?
    let categoryName: String?

    var body: some View {
        HStack(spacing: 12) {
            WorkoutVisual(
                workoutID: step.workoutID,
                categoryID: workout?.categoryID,
                categoryName: categoryName,
                variant: .smallRow
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.workoutNameSnapshot)
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("routineDetail.step.\(index).title")
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
                    .monospacedDigit()
                    .accessibilityIdentifier("routineDetail.step.\(index).summary")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PlatformColors.groupedSurface, in: .rect(cornerRadius: ShapeRadius.card))
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("routineDetail.step.\(index)")
    }

    private var summary: String {
        RoutineStepFormatting.summary(
            workSeconds: step.workSeconds,
            sets: step.sets,
            setRestSeconds: step.setRestSeconds,
            repGuidance: step.repGuidance
        )
    }

    private var accessibilitySummary: String {
        [
            step.workoutNameSnapshot,
            RoutineStepFormatting.summary(
                workSeconds: step.workSeconds,
                sets: step.sets,
                setRestSeconds: step.setRestSeconds,
                repGuidance: step.repGuidance,
                spoken: true
            )
        ].joined(separator: L10n.summarySeparator)
    }
}
