import SwiftUI

struct RoutineBuilderStepEditor: View {
    @Binding var step: RoutineDraftStep
    let index: Int
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Stepper(value: $step.workSeconds, in: 5...600, step: 5) {
                valueRow(label: L10n.builderStepWork, value: DisplayFormatters.duration(step.workSeconds))
            }
            .accessibilityIdentifier("builder.step.\(index).work")

            Divider()

            Stepper(value: $step.sets, in: 1...20, step: 1) {
                valueRow(label: L10n.builderStepSets, value: step.sets.formatted())
            }
            .accessibilityIdentifier("builder.step.\(index).sets")

            Divider()

            Stepper(value: $step.setRestSeconds, in: 0...300, step: 5) {
                valueRow(label: L10n.builderStepSetRest, value: restValue(step.setRestSeconds))
            }
            .accessibilityIdentifier("builder.step.\(index).setRest")

            Divider()

            Stepper(value: repGuidanceBinding, in: 0...100, step: 5) {
                valueRow(label: L10n.builderStepRepGuidance, value: repGuidanceValue)
            }
            .accessibilityIdentifier("builder.step.\(index).repGuidance")

            Divider()

            Stepper(value: $step.restAfterSeconds, in: 0...300, step: 5) {
                valueRow(label: L10n.builderStepRestAfter, value: restValue(step.restAfterSeconds))
            }
            .accessibilityHint(isLast ? L10n.builderStepRestAfterFootnote : "")
            .accessibilityIdentifier("builder.step.\(index).restAfter")

            if isLast {
                Text(L10n.builderStepRestAfterFootnote)
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            PlatformColors.groupedSurface,
            in: .rect(corners: .concentric(minimum: .fixed(ShapeRadius.insetRow)), isUniform: false)
        )
        .overlay {
            ConcentricRectangle(corners: .concentric(minimum: .fixed(ShapeRadius.insetRow)), isUniform: false)
                .stroke(Color("PulseAzureSoft"), lineWidth: 2)
        }
    }

    private var repGuidanceBinding: Binding<Int> {
        Binding {
            step.repGuidance ?? 0
        } set: { newValue in
            step.repGuidance = newValue == 0 ? nil : newValue
        }
    }

    private var repGuidanceValue: String {
        if let repGuidance = step.repGuidance {
            L10n.reps(repGuidance)
        } else {
            L10n.builderStepOff
        }
    }

    private func restValue(_ seconds: Int) -> String {
        seconds == 0 ? L10n.builderStepOff : DisplayFormatters.duration(seconds)
    }

    private func valueRow(label: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.primary)
        } label: {
            Text(label)
        }
        .font(.body)
    }
}
