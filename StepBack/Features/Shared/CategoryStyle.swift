import SwiftUI

struct CategoryStyle: Hashable {
    let colorAssetName: String
    let symbolName: String

    var color: Color {
        Color(colorAssetName)
    }

    var softColor: Color {
        color.opacity(0.13)
    }

    static func resolve(_ categoryID: String?) -> CategoryStyle {
        switch categoryID {
        case "full-body":
            CategoryStyle(colorAssetName: "CategoryFullBody", symbolName: "figure.mixed.cardio")
        case "core":
            CategoryStyle(colorAssetName: "CategoryCore", symbolName: "figure.core.training")
        case "arms-shoulders":
            CategoryStyle(colorAssetName: "CategoryArmsShoulders", symbolName: "dumbbell.fill")
        case "chest-back":
            CategoryStyle(colorAssetName: "CategoryChestBack", symbolName: "figure.strengthtraining.traditional")
        case "legs-glutes":
            CategoryStyle(colorAssetName: "CategoryLegsGlutes", symbolName: "figure.strengthtraining.functional")
        case "cardio":
            CategoryStyle(colorAssetName: "CategoryCardio", symbolName: "figure.run")
        case "mobility-stretch":
            CategoryStyle(colorAssetName: "CategoryMobilityStretch", symbolName: "figure.flexibility")
        case "balance":
            CategoryStyle(colorAssetName: "CategoryBalance", symbolName: "figure.yoga")
        default:
            CategoryStyle(colorAssetName: "PulseAzureSoft", symbolName: "figure.strengthtraining.functional")
        }
    }
}
