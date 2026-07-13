import SwiftUI

struct CategoryWorkoutsView: View {
    let section: GallerySection
    let categoryName: String
    let addCustom: () -> Void
    let selectWorkout: (WorkoutItem) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88, maximum: 160), spacing: 16)],
                spacing: 16
            ) {
                ForEach(section.items) { item in
                    WorkoutTile(
                        item: item,
                        categoryName: categoryName,
                        open: { selectWorkout(item) }
                    )
                }
                AddCustomWorkoutTile(action: addCustom)
            }
            .padding(16)
        }
        .navigationTitle(categoryName)
        .inlineNavigationTitleOnMobile()
    }
}
