import SwiftUI

struct AddCustomWorkoutTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        RoundedRectangle(cornerRadius: ShapeRadius.card)
                            .stroke(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                Text(L10n.addYourOwn)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(PlatformColors.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gallery.addCustom")
    }
}
