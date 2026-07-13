import SwiftUI

struct WelcomeFeatureRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color("PulseAzure"))
                .frame(width: 40, height: 40)
                .background(Color("PulseAzureSoft"), in: .rect(cornerRadius: ShapeRadius.tileSmall))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(PlatformColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
