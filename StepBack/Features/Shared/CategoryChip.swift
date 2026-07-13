import SwiftUI

struct CategoryChip: View {
    let title: String
    let categoryID: String

    var body: some View {
        let style = CategoryStyle.resolve(categoryID)
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: style.symbolName)
                .foregroundStyle(style.color)
        }
            .font(.footnote.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.softColor, in: .capsule)
            .accessibilityElement(children: .combine)
    }
}
