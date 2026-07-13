import SwiftData
import SwiftUI
import StepBackCore

struct GalleryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var customWorkouts: [CustomWorkout]
    @Query private var routines: [Routine]
    @State private var path: [GalleryRoute] = []
    @State private var searchText = ""
    @State private var editorRequest: CustomEditorRequest?
    private let selectWorkout: ((WorkoutItem) -> Void)?
    private let selectRoutine: ((String) -> Void)?

    init(
        selectWorkout: ((WorkoutItem) -> Void)? = nil,
        selectRoutine: ((String) -> Void)? = nil
    ) {
        self.selectWorkout = selectWorkout
        self.selectRoutine = selectRoutine
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if searchText.isEmpty, horizontalSizeClass == .compact {
                    compactBrowse
                } else {
                    sectionedBrowse
                }
            }
            .navigationTitle(L10n.tabGallery)
            .searchable(text: $searchText, prompt: L10n.searchPrompt(allItems.count))
            .accessibilityIdentifier("gallery.search")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.addYourOwn, systemImage: "plus") {
                        editorRequest = CustomEditorRequest(mode: .create(categoryID: "full-body"))
                    }
                    .accessibilityIdentifier("gallery.addCustom")
                }
            }
            .navigationDestination(for: GalleryRoute.self, destination: destination)
            .sheet(item: $editorRequest) { request in
                CustomWorkoutEditor(
                    workout: existingWorkout(for: request),
                    initialCategoryID: initialCategoryID(for: request)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .background(PlatformColors.groupedBackground.ignoresSafeArea())
        }
    }

    private var compactBrowse: some View {
        List(sections) { section in
            NavigationLink(value: GalleryRoute.category(section.id)) {
                GallerySectionHeader(
                    section: section,
                    categoryName: categoryName(section.category)
                )
                .padding(.vertical, 8)
            }
        }
    }

    private var sectionedBrowse: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        GallerySectionHeader(
                            section: section,
                            categoryName: categoryName(section.category)
                        )
                        LazyVGrid(columns: tileColumns, spacing: 16) {
                            ForEach(section.items) { item in
                                WorkoutTile(
                                    item: item,
                                    categoryName: categoryName(section.category),
                                    open: { openWorkout(item) }
                                )
                            }
                            if searchText.isEmpty {
                                AddCustomWorkoutTile {
                                    editorRequest = CustomEditorRequest(mode: .create(categoryID: section.id))
                                }
                            }
                        }
                    }
                }
            }
            .padding(horizontalSizeClass == .compact ? 16 : 24)
        }
        .overlay {
            if !searchText.isEmpty, filteredItems.isEmpty {
                ContentUnavailableView.search
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: GalleryRoute) -> some View {
        switch route {
        case let .category(categoryID):
            if let section = sections.first(where: { $0.id == categoryID }) {
                CategoryWorkoutsView(
                    section: section,
                    categoryName: categoryName(section.category),
                    addCustom: {
                        editorRequest = CustomEditorRequest(mode: .create(categoryID: categoryID))
                    },
                    selectWorkout: openWorkout
                )
            }
        case let .workout(item):
            WorkoutDetailView(
                item: item,
                onCreatedRoutine: openRoutine,
                onDeleted: { if !path.isEmpty { path.removeLast() } }
            )
        case let .routine(id):
            if let routine = routines.first(where: { $0.id == id }) {
                RoutineDetailView(routine: routine)
            }
        }
    }

    private var allItems: [WorkoutItem] {
        WorkoutLibrary.allItems(catalogService: catalogService, customWorkouts: customWorkouts)
    }

    private var filteredItems: [WorkoutItem] {
        WorkoutLibrary.search(allItems, query: searchText)
    }

    private var sections: [GallerySection] {
        catalogService.catalog.categories.compactMap { category in
            let items = WorkoutLibrary.sortedForSearch(
                filteredItems.filter { $0.categoryID == category.id },
                query: searchText
            )
            guard !items.isEmpty || searchText.isEmpty else { return nil }
            return GallerySection(category: category, items: items)
        }
    }

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 88 : 108, maximum: 160), spacing: 16)]
    }

    private func categoryName(_ category: StepBackCore.WorkoutCategory) -> String {
        catalogService.localizedString(for: category.nameKey)
    }

    private func existingWorkout(for request: CustomEditorRequest) -> CustomWorkout? {
        guard case let .edit(workoutID) = request.mode else { return nil }
        return customWorkouts.first { $0.id == workoutID }
    }

    private func initialCategoryID(for request: CustomEditorRequest) -> String {
        switch request.mode {
        case let .create(categoryID):
            categoryID
        case let .edit(workoutID):
            customWorkouts.first { $0.id == workoutID }?.categoryID ?? "full-body"
        }
    }

    private func openWorkout(_ item: WorkoutItem) {
        if let selectWorkout {
            selectWorkout(item)
        } else {
            path.append(.workout(item))
        }
    }

    private func openRoutine(_ id: String) {
        if let selectRoutine {
            selectRoutine(id)
        } else {
            path.append(.routine(id))
        }
    }
}
