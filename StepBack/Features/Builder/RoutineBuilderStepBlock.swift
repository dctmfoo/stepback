import SwiftUI

struct RoutineBuilderStepBlock: View {
    @Binding var step: RoutineDraftStep
    let index: Int
    let isExpanded: Bool
    let isLast: Bool
    let workout: WorkoutItem?
    let categoryName: String?
    let toggleExpanded: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
                    .draggable(step.id)
                    .accessibilityLabel(L10n.builderStepAccessibility(step.workoutNameSnapshot, summary))
                    .accessibilityHint(isExpanded ? L10n.builderStepCollapseHint : L10n.builderStepExpandHint)
                    .accessibilityIdentifier("builder.step.\(index).drag")

                Button(action: toggleExpanded) {
                    HStack(spacing: 12) {
                        WorkoutVisual(
                            workoutID: step.workoutID,
                            categoryID: workout?.categoryID,
                            categoryName: categoryName,
                            variant: .smallRow
                        )
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.workoutNameSnapshot)
                                .font(.body.bold())
                                .foregroundStyle(.primary)
                            Text(summary)
                                .font(.footnote)
                                .foregroundStyle(PlatformColors.secondaryText)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(Color("PulseAzure"))
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.builderStepAccessibility(step.workoutNameSnapshot, summary))
                .accessibilityHint(isExpanded ? L10n.builderStepCollapseHint : L10n.builderStepExpandHint)
                .accessibilityIdentifier("builder.step.\(index)")
                .accessibilityAction(named: Text(L10n.builderStepDelete)) {
                    delete()
                }
                .contextMenu {
                    Button(L10n.builderStepDelete, systemImage: "trash", role: .destructive, action: delete)
                }

                Menu {
                    Button(action: moveUp) {
                        Label(L10n.builderStepMoveUp, systemImage: "chevron.up")
                    }
                    .disabled(!canMoveUp)
                    .accessibilityIdentifier("builder.step.\(index).moveUp")

                    Button(action: moveDown) {
                        Label(L10n.builderStepMoveDown, systemImage: "chevron.down")
                    }
                    .disabled(!canMoveDown)
                    .accessibilityIdentifier("builder.step.\(index).moveDown")

                    Divider()

                    Button(role: .destructive, action: delete) {
                        Label(L10n.builderStepDelete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PlatformColors.secondaryText)
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.builderStepActions)
                .accessibilityIdentifier("builder.step.\(index).actions")
            }
            .contentShape(.rect)

            if isExpanded {
                RoutineBuilderStepEditor(step: $step, index: index, isLast: isLast)
            } else if !isLast, step.restAfterSeconds > 0 {
                Button(action: toggleExpanded) {
                    RoutineRestRow(
                        seconds: step.restAfterSeconds,
                        index: index,
                        accessibilityIdentifier: "builder.step.\(index).rest"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .containerShape(.rect(cornerRadius: ShapeRadius.card))
        .listRowSeparator(.hidden)
    }

    private var summary: String {
        RoutineStepFormatting.summary(
            workSeconds: step.workSeconds,
            sets: step.sets,
            setRestSeconds: step.setRestSeconds,
            repGuidance: step.repGuidance
        )
    }
}
