import SwiftUI

struct WelcomeView: View {
    let getStarted: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "figure.run")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color("PulseAzure"))
                    .frame(width: 88, height: 88)
                    .background(Color("PulseAzureSoft"), in: .rect(cornerRadius: ShapeRadius.cardProminent))
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(L10n.welcomeTitle)
                        .font(.largeTitle.bold())
                    Text(L10n.welcomeTagline)
                        .font(.body)
                        .foregroundStyle(PlatformColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("welcome.tagline")
                }

                VStack(spacing: 20) {
                    WelcomeFeatureRow(
                        title: L10n.welcomeCompose,
                        detail: L10n.welcomeComposeDetail,
                        systemImage: "rectangle.stack.badge.plus",
                        accessibilityIdentifier: "welcome.compose"
                    )
                    WelcomeFeatureRow(
                        title: L10n.welcomePlay,
                        detail: L10n.welcomePlayDetail,
                        systemImage: "play.fill",
                        accessibilityIdentifier: "welcome.play"
                    )
                    WelcomeFeatureRow(
                        title: L10n.welcomeFollow,
                        detail: L10n.welcomeFollowDetail,
                        systemImage: "speaker.wave.2.fill",
                        accessibilityIdentifier: "welcome.follow"
                    )
                }

                Label(L10n.welcomePrivacy, systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("welcome.privacy")

                Button(L10n.welcomeGetStarted, action: getStarted)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("welcome.getStarted")
            }
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(PlatformColors.groupedBackground.ignoresSafeArea())
        .tint(Color("PulseAzure"))
        .accessibilityIdentifier("welcome.screen")
    }
}
