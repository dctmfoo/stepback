import SwiftUI

struct WorkoutTile: View {
    let item: WorkoutItem
    let categoryName: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 8) {
                WorkoutVisual(
                    workout: item,
                    categoryName: categoryName,
                    variant: .galleryCard
                )
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if item.isCustom {
                    Text(L10n.yours)
                        .font(.caption)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier("gallery.tile.\(item.id)")
        }
        .buttonStyle(.plain)
    }

    private var accessibilityLabel: String {
        var parts = [item.name, categoryName]
        if item.isCustom { parts.append(L10n.yours) }
        return parts.joined(separator: L10n.summarySeparator)
    }
}
