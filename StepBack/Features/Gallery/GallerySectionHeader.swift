import SwiftUI

struct GallerySectionHeader: View {
    let section: GallerySection
    let categoryName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: CategoryStyle.resolve(section.id).symbolName)
                .foregroundStyle(CategoryStyle.resolve(section.id).color)
                .accessibilityHidden(true)
            Text(categoryName)
                .font(.headline)
            Spacer()
            Text(countLabel)
                .font(.footnote)
                .foregroundStyle(PlatformColors.secondaryText)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gallery.section.\(section.id)")
    }

    private var countLabel: String {
        var parts = [L10n.categoryCount(section.items.count)]
        if section.customCount > 0 {
            parts.append(L10n.categoryYours(section.customCount))
        }
        return parts.joined(separator: L10n.summarySeparator)
    }
}
