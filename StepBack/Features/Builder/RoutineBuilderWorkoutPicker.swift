import StepBackCore
import SwiftUI

struct RoutineBuilderWorkoutPicker: View {
    @Bindable var model: RoutineBuilderModel
    let workouts: [WorkoutItem]
    let categories: [WorkoutCategory]
    let categoryName: (WorkoutCategory) -> String
    let dismiss: () -> Void
    let commit: () -> Void

    var body: some View {
        let visible = visibleWorkouts
        let selected = selectedWorkouts
        let selectedIDs = Set(model.pickerSelectionIDs)

        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    pickerTitle
                    Spacer()
                    closeButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        closeButton
                    }
                    pickerTitle
                }
            }

            TextField(L10n.builderPickerSearch, text: $model.pickerSearchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(L10n.builderPickerSearch)
                .accessibilityIdentifier("builder.picker.search")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    categoryChip(title: L10n.builderPickerAll, categoryID: nil, symbolName: "square.grid.2x2")
                    ForEach(categories, id: \.id) { category in
                        categoryChip(
                            title: categoryName(category),
                            categoryID: category.id,
                            symbolName: CategoryStyle.resolve(category.id).symbolName
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("builder.picker.categories")

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visible) { workout in
                        Button {
                            model.togglePickerSelection(workout.id)
                        } label: {
                            pickerRow(workout, isSelected: selectedIDs.contains(workout.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("builder.picker.row.\(workout.id)")
                    }

                    if visible.isEmpty {
                        ContentUnavailableView.search
                    }
                }
            }
            .accessibilityIdentifier("builder.picker.workouts")

            selectionTray(selectedWorkouts: selected)
        }
        .padding(20)
        .background(PlatformColors.groupedBackground.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: model.pickerSelectionIDs)
    }

    private var visibleWorkouts: [WorkoutItem] {
        let categoryFiltered = if let selectedCategoryID = model.selectedCategoryID {
            workouts.filter { $0.categoryID == selectedCategoryID }
        } else {
            workouts
        }
        return WorkoutLibrary.sortedForSearch(
            WorkoutLibrary.search(categoryFiltered, query: model.pickerSearchText),
            query: model.pickerSearchText
        )
    }

    private var selectedWorkouts: [WorkoutItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: workouts.map { ($0.id, $0) })
        return model.pickerSelectionIDs.compactMap { itemsByID[$0] }
    }

    private func selectionTray(selectedWorkouts: [WorkoutItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedWorkouts.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Text(L10n.builderPickerSelected)
                            .font(.caption.bold())
                            .foregroundStyle(PlatformColors.secondaryText)
                        ForEach(selectedWorkouts) { workout in
                            Button {
                                model.togglePickerSelection(workout.id)
                            } label: {
                                WorkoutVisual(
                                    workout: workout,
                                    categoryName: categoryName(for: workout.categoryID),
                                    variant: .smallRow,
                                    cornerStyle: .concentric
                                )
                                .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .containerShape(.rect(cornerRadius: ShapeRadius.insetRow))
                            .accessibilityLabel(workout.name)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("builder.picker.tray")
            }

            Button(action: commit) {
                Text(L10n.builderPickerAddCount(selectedWorkouts.count))
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(selectedWorkouts.isEmpty)
                .accessibilityIdentifier("builder.picker.add")
        }
    }

    private var pickerTitle: some View {
        Text(L10n.builderAddWorkouts)
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("builder.picker.title")
    }

    private var closeButton: some View {
        Button(L10n.cancel, systemImage: "xmark", action: dismiss)
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("builder.picker.close")
    }

    private func categoryChip(
        title: String,
        categoryID: String?,
        symbolName: String
    ) -> some View {
        Button {
            model.selectedCategoryID = categoryID
        } label: {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("builder.picker.chip.label.\(categoryID ?? "all")")
            } icon: {
                Image(systemName: symbolName)
                    .foregroundStyle(
                        model.selectedCategoryID == categoryID ? Color("PulseAzure") : .primary
                    )
            }
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    model.selectedCategoryID == categoryID ? Color("PulseAzureSoft") : PlatformColors.groupedSurface,
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityIdentifier("builder.picker.chip.\(categoryID ?? "all")")
    }

    private func pickerRow(_ workout: WorkoutItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            WorkoutVisual(
                workout: workout,
                categoryName: categoryName(for: workout.categoryID),
                variant: .smallRow
            )
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("builder.picker.row.label.\(workout.id)")
                if workout.isCustom {
                    Text(L10n.yours)
                        .font(.footnote)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color("PulseAzure")) : AnyShapeStyle(.tertiary))
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(PlatformColors.groupedSurface, in: .rect(cornerRadius: ShapeRadius.insetRow))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }

    private func categoryName(for categoryID: String) -> String? {
        guard let category = categories.first(where: { $0.id == categoryID }) else { return nil }
        return categoryName(category)
    }
}
