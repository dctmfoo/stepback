import SwiftUI

struct PlayerStackedSegmentLayout: Layout {
    let visualHeight: CGFloat
    private let bandSpacing: CGFloat = 24
    private let footClearance: CGFloat = 20

    static var layoutProperties: LayoutProperties {
        var properties = LayoutProperties()
        properties.stackOrientation = .vertical
        return properties
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else {
            return proposal.replacingUnspecifiedDimensions()
        }

        let heroSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: proposal.width, height: nil)
        )
        let visualSize = subviews[1].sizeThatFits(
            visualProposal(maxWidth: proposal.width, height: visualHeight)
        )
        return CGSize(
            width: proposal.width ?? max(heroSize.width, visualSize.width),
            height: proposal.height ?? heroSize.height + visualSize.height + bandSpacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }

        let usableHeight = max(0, bounds.height - footClearance)
        let idealHeroSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: bounds.width, height: nil)
        )
        let availableVisualHeight = max(
            0,
            usableHeight - idealHeroSize.height - bandSpacing
        )
        let placedVisualHeight = min(visualHeight, availableVisualHeight)
        let heroHeightLimit = max(
            0,
            usableHeight - placedVisualHeight - bandSpacing
        )
        let heroSize = subviews[0].sizeThatFits(
            ProposedViewSize(width: bounds.width, height: heroHeightLimit)
        )
        let visualProposal = visualProposal(
            maxWidth: bounds.width,
            height: placedVisualHeight
        )
        let visualSize = subviews[1].sizeThatFits(visualProposal)

        let remainingHeight = max(
            0,
            usableHeight - heroSize.height - visualSize.height - bandSpacing
        )
        let outerBreathingSpace = remainingHeight / 4
        let bandGap = bandSpacing + remainingHeight / 2
        let centerX = bounds.midX
        let heroY = bounds.minY + outerBreathingSpace
        let visualY = heroY + heroSize.height + bandGap

        subviews[0].place(
            at: CGPoint(x: centerX, y: heroY),
            anchor: .top,
            proposal: ProposedViewSize(width: bounds.width, height: heroSize.height)
        )
        subviews[1].place(
            at: CGPoint(x: centerX, y: visualY),
            anchor: .top,
            proposal: visualProposal
        )
    }

    private func visualProposal(maxWidth: CGFloat?, height: CGFloat) -> ProposedViewSize {
        ProposedViewSize(
            width: min(maxWidth ?? height * 4 / 3, height * 4 / 3),
            height: height
        )
    }
}
