import SwiftUI

struct RoutineBuilderFloatingBar: View {
    let totalSeconds: Int
    let addWorkouts: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(L10n.builderAddWorkouts, systemImage: "plus", action: addWorkouts)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("builder.addWorkouts")

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.builderTotal)
                    .font(.caption.bold())
                    .foregroundStyle(PlatformColors.secondaryText)
                Text(DisplayFormatters.duration(totalSeconds))
                    .font(.headline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.builderTotal)
            .accessibilityValue(DisplayFormatters.spokenDuration(totalSeconds))
            .accessibilityIdentifier("builder.total")
        }
        .padding(8)
        .background(.regularMaterial, in: .capsule)
    }
}
