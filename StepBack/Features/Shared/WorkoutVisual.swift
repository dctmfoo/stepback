import SwiftUI

struct WorkoutVisual: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Variant {
        case smallRow
        case galleryCard
        case detailHeader
        case stage
    }

    enum CornerStyle {
        case fixed
        case concentric
    }

    let workoutID: String
    let categoryID: String?
    let categoryName: String?
    let variant: Variant
    let cornerStyle: CornerStyle

    init(workout: WorkoutItem, categoryName: String?, variant: Variant, cornerStyle: CornerStyle = .fixed) {
        workoutID = workout.id
        categoryID = workout.categoryID
        self.categoryName = categoryName
        self.variant = variant
        self.cornerStyle = cornerStyle
    }

    init(
        workoutID: String,
        categoryID: String?,
        categoryName: String?,
        variant: Variant,
        cornerStyle: CornerStyle = .fixed
    ) {
        self.workoutID = workoutID
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.variant = variant
        self.cornerStyle = cornerStyle
    }

    var body: some View {
        let style = CategoryStyle.resolve(categoryID)
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background {
                background(style: style)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(variant == .stage ? "player.visual.category" : "")
            .accessibilityHidden(true)
            .overlay {
                visualContent(style: style)
            }
            .clipped()
    }

    @ViewBuilder
    private func visualContent(style: CategoryStyle) -> some View {
        if variant == .stage {
            visualLabel(style: style)
                .accessibilityHidden(true)
        } else {
            visualLabel(style: style)
        }
    }

    private func visualLabel(style: CategoryStyle) -> some View {
        VStack(spacing: 8) {
            Image(systemName: style.symbolName)
                .font(symbolFont)
                .foregroundStyle(style.color)
            if showsCategoryName,
               !(variant == .stage && dynamicTypeSize.isAccessibilitySize),
               let categoryName {
                Text(categoryName.uppercased())
                    .font(.caption.bold())
                    .tracking(1)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(8)
    }

    private var symbolFont: Font {
        switch variant {
        case .smallRow:
            .headline
        case .galleryCard:
            .title2
        case .detailHeader, .stage:
            .largeTitle
        }
    }

    private var aspectRatio: Double {
        switch variant {
        case .smallRow, .galleryCard:
            1
        case .detailHeader, .stage:
            4 / 3
        }
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .smallRow:
            ShapeRadius.tileSmall
        case .galleryCard:
            ShapeRadius.tileMedium
        case .detailHeader, .stage:
            ShapeRadius.tileLarge
        }
    }

    @ViewBuilder
    private func background(style: CategoryStyle) -> some View {
        switch cornerStyle {
        case .fixed:
            style.softColor
                .clipShape(.rect(cornerRadius: cornerRadius))
        case .concentric:
            style.softColor
                .clipShape(.rect(corners: .concentric(minimum: .fixed(cornerRadius)), isUniform: false))
        }
    }

    private var showsCategoryName: Bool {
        switch variant {
        case .detailHeader, .stage:
            true
        case .smallRow, .galleryCard:
            false
        }
    }
}
