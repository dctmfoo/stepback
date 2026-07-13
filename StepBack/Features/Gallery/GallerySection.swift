import StepBackCore

struct GallerySection: Identifiable {
    let category: WorkoutCategory
    let items: [WorkoutItem]

    var id: String { category.id }

    var customCount: Int {
        items.count(where: \.isCustom)
    }
}
