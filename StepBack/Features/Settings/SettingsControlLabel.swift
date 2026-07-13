import SwiftUI

struct SettingsControlLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(PlatformColors.secondaryText)
        }
    }
}
