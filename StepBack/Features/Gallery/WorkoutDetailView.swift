import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var customWorkouts: [CustomWorkout]
    @Query private var routines: [Routine]
    @State private var addRequest: WorkoutItem?
    @State private var editorRequest: CustomEditorRequest?
    @State private var deleteIsPresented = false
    @State private var errorIsPresented = false
    let item: WorkoutItem
    let onCreatedRoutine: (String) -> Void
    let onDeleted: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                WorkoutVisual(
                    workout: displayedItem,
                    categoryName: categoryName,
                    variant: .detailHeader
                )
                .accessibilityLabel([displayedItem.name, categoryName].joined(separator: L10n.summarySeparator))
                .accessibilityIdentifier("workoutDetail.visual")

                Text(displayedItem.name)
                    .font(.title.bold())

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        CategoryChip(title: categoryName, categoryID: displayedItem.categoryID)
                        ForEach(displayedItem.focusAreas, id: \.self) { focusArea in
                            Text(catalogService.localizedString(for: "focus.\(focusArea)"))
                                .font(.footnote.bold())
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.quaternary, in: .capsule)
                        }
                    }
                }
                .scrollIndicators(.hidden)

                if let notes = displayedItem.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(PlatformColors.secondaryText)
                }

                if !containingRoutines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.appearsIn(containingRoutines.count))
                            .font(.footnote.bold())
                        Text(containingRoutineNames)
                            .font(.footnote)
                            .foregroundStyle(PlatformColors.secondaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PlatformColors.groupedSurface, in: .rect(cornerRadius: ShapeRadius.card))
                }

                Button(L10n.addToRoutine, systemImage: "plus") {
                    addRequest = displayedItem
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("workoutDetail.addToRoutine")
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(displayedItem.name)
        .inlineNavigationTitleOnMobile()
        .toolbar {
            if displayedItem.isCustom {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(L10n.editWorkout, systemImage: "pencil") {
                        editorRequest = CustomEditorRequest(mode: .edit(workoutID: displayedItem.id))
                    }
                    .accessibilityIdentifier("workoutDetail.edit")
                    Button(L10n.deleteWorkout, systemImage: "trash", role: .destructive) {
                        deleteIsPresented = true
                    }
                    .accessibilityIdentifier("workoutDetail.delete")
                }
            }
        }
        .sheet(item: $addRequest) { workout in
            AddToRoutineSheet(workout: workout, onCreatedRoutine: onCreatedRoutine)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editorRequest) { _ in
            CustomWorkoutEditor(
                workout: customWorkouts.first { $0.id == displayedItem.id },
                initialCategoryID: displayedItem.categoryID,
                onDeleted: onDeleted
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            L10n.deleteWorkoutTitle(displayedItem.name),
            isPresented: $deleteIsPresented
        ) {
            Button(L10n.deleteWorkout, role: .destructive, action: deleteWorkout)
        } message: {
            Text(L10n.deleteWorkoutMessage)
        }
        .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
            Button(L10n.dismiss, role: .cancel) {}
        } message: {
            Text(L10n.errorMessage)
        }
        .background(PlatformColors.groupedBackground.ignoresSafeArea())
        .onAppear(perform: dismissSearch.callAsFunction)
    }

    private var displayedItem: WorkoutItem {
        guard item.isCustom, let current = customWorkouts.first(where: { $0.id == item.id }) else {
            return item
        }
        return .custom(current)
    }

    private var categoryName: String {
        guard let category = catalogService.catalog.categories.first(where: { $0.id == displayedItem.categoryID }) else {
            return L10n.category
        }
        return catalogService.localizedString(for: category.nameKey)
    }

    private var containingRoutines: [Routine] {
        WorkoutLibrary.routines(containing: displayedItem.id, in: routines)
    }

    private var containingRoutineNames: String {
        let visibleNames = containingRoutines.prefix(3).map(\.name)
        let moreCount = containingRoutines.count - visibleNames.count
        var parts = [DisplayFormatters.list(visibleNames)]
        if moreCount > 0 { parts.append(L10n.appearsInMore(moreCount)) }
        return parts.joined(separator: L10n.summarySeparator)
    }

    private func deleteWorkout() {
        guard let custom = customWorkouts.first(where: { $0.id == displayedItem.id }) else { return }
        do {
            modelContext.delete(custom)
            try modelContext.saveOrRollback()
            onDeleted()
        } catch {
            errorIsPresented = true
        }
    }
}
