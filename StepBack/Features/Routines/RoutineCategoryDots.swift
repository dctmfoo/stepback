import SwiftUI

struct RoutineCategoryDots: View {
    let categoryIDs: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(categoryIDs, id: \.self) { categoryID in
                Circle()
                    .fill(CategoryStyle.resolve(categoryID).color)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
    }
}
