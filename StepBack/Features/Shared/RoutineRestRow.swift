import SwiftUI

struct RoutineRestRow: View {
    let seconds: Int
    let index: Int
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Label {
            Text(L10n.rest(DisplayFormatters.duration(seconds)))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("routineDetail.rest.\(index).label")
        } icon: {
            Image(systemName: "clock")
                .foregroundStyle(Color("RecoverMint"))
        }
            .font(.footnote.bold())
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color("RecoverMintSoft"), in: .rect(cornerRadius: ShapeRadius.insetRow))
            .foregroundStyle(.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.accessibilityRest(DisplayFormatters.spokenDuration(seconds)))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(accessibilityIdentifier ?? "routineDetail.rest.\(index)")
    }
}
