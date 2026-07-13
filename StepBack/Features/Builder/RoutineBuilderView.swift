import StepBackCore
import SwiftData
import SwiftUI

struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var customWorkouts: [CustomWorkout]
    @State private var model: RoutineBuilderModel
    @State private var pickerIsPresented = false
    @State private var scrollTargetStepID: RoutineDraftStep.ID?
    @State private var discardIsPresented = false
    @State private var errorIsPresented = false
    @State private var saveFeedback = 0

    let title: String
    let existingRoutine: Routine?
    let onSave: (Routine) -> Void

    init(
        title: String,
        model: RoutineBuilderModel,
        existingRoutine: Routine? = nil,
        onSave: @escaping (Routine) -> Void
    ) {
        self.title = title
        _model = State(initialValue: model)
        self.existingRoutine = existingRoutine
        self.onSave = onSave
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Group {
                if usesSideBySidePicker, pickerIsPresented {
                    HStack(spacing: 0) {
                        stepList
                            .frame(maxWidth: 620)
                        Divider()
                        RoutineBuilderWorkoutPicker(
                            model: model,
                            workouts: allWorkouts,
                            categories: catalogService.catalog.categories,
                            categoryName: categoryName,
                            dismiss: hidePicker,
                            commit: commitPickerSelection
                        )
                        .frame(minWidth: 320, maxWidth: 420)
                    }
                } else {
                    stepList
                }
            }
            .navigationTitle(title)
            .inlineNavigationTitleOnMobile()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel, action: cancel)
                        .accessibilityIdentifier("builder.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save, action: save)
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("builder.save")
                }
            }
            .safeAreaInset(edge: .bottom) {
                RoutineBuilderFloatingBar(
                    totalSeconds: model.totalSeconds,
                    addWorkouts: showPicker
                )
                .padding(.horizontal, horizontalSizeClass == .compact ? 16 : 24)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: compactPickerIsPresented) {
                RoutineBuilderWorkoutPicker(
                    model: model,
                    workouts: allWorkouts,
                    categories: catalogService.catalog.categories,
                    categoryName: categoryName,
                    dismiss: hidePicker,
                    commit: commitPickerSelection
                )
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(L10n.builderDiscardTitle, isPresented: $discardIsPresented) {
                Button(L10n.builderDiscardConfirm, role: .destructive) {
                    dismiss()
                }
                .accessibilityIdentifier("builder.discard.confirm")
                Button(L10n.builderDiscardKeep, role: .cancel) {}
            }
            .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text(L10n.errorMessage)
            }
            .interactiveDismissDisabled(model.isDirty)
            .sensoryFeedback(.success, trigger: saveFeedback)
            .background(PlatformColors.groupedBackground.ignoresSafeArea())
        }
    }

    private var stepList: some View {
        @Bindable var model = model
        let workoutLookup = workoutItemsByID

        return ScrollViewReader { proxy in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.builderNameLabel.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(PlatformColors.secondaryText)
                            .accessibilityIdentifier("builder.name.label")
                        TextField(L10n.builderNameLabel, text: $model.name)
                            .font(.body.bold())
                            .routineNameInputStyle()
                            .accessibilityIdentifier("builder.name")
                    }
                    .padding(.vertical, 4)
                }

                if model.steps.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.badge.plus")
                                .font(.largeTitle)
                                .accessibilityHidden(true)
                            Text(L10n.builderEmptyTitle)
                                .font(.title3.bold())
                            Text(L10n.builderEmptyMessage)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("builder.empty")
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                            let workout = workoutLookup[step.workoutID]
                            RoutineBuilderStepBlock(
                                step: binding(for: step.id),
                                index: index,
                                isExpanded: model.expandedStepID == step.id,
                                isLast: index == model.steps.index(before: model.steps.endIndex),
                                workout: workout,
                                categoryName: categoryName(for: workout?.categoryID),
                                toggleExpanded: { model.toggleExpandedStep(id: step.id) },
                                canMoveUp: index > model.steps.startIndex,
                                canMoveDown: index < model.steps.index(before: model.steps.endIndex),
                                moveUp: { model.moveStepUp(id: step.id) },
                                moveDown: { model.moveStepDown(id: step.id) },
                                delete: { model.deleteStep(id: step.id) }
                            )
                            .id(step.id)
                            .dropDestination(for: String.self) { stepIDs, _ in
                                guard let sourceID = stepIDs.first else { return false }
                                model.moveStep(id: sourceID, before: step.id)
                                return true
                            }
                        }
                        .onMove(perform: model.moveSteps)
                        .onDelete { offsets in
                            for id in offsets.map({ model.steps[$0].id }) {
                                model.deleteStep(id: id)
                            }
                        }

                        Color.clear
                            .frame(height: 28)
                            .dropDestination(for: String.self) { stepIDs, _ in
                                guard let sourceID = stepIDs.first else { return false }
                                model.moveStepToEnd(id: sourceID)
                                return true
                            }
                            .accessibilityHidden(true)
                    }
                }
            }
            .routineBuilderListStyle()
            .scrollContentBackground(.visible)
            .onChange(of: scrollTargetStepID) { _, stepID in
                guard let stepID else { return }
                Task { @MainActor in
                    await Task.yield()
                    if reduceMotion {
                        proxy.scrollTo(stepID, anchor: .center)
                    } else {
                        withAnimation {
                            proxy.scrollTo(stepID, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var usesSideBySidePicker: Bool {
        horizontalSizeClass != .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var compactPickerIsPresented: Binding<Bool> {
        Binding(
            get: { pickerIsPresented && !usesSideBySidePicker },
            set: { if !$0 { pickerIsPresented = false } }
        )
    }

    private var allWorkouts: [WorkoutItem] {
        WorkoutLibrary.allItems(catalogService: catalogService, customWorkouts: customWorkouts)
    }

    private var workoutItemsByID: [String: WorkoutItem] {
        Dictionary(uniqueKeysWithValues: allWorkouts.map { ($0.id, $0) })
    }

    private func binding(for stepID: RoutineDraftStep.ID) -> Binding<RoutineDraftStep> {
        Binding {
            model.steps.first { $0.id == stepID } ?? RoutineDraftStep(
                workoutID: "missing",
                workoutNameSnapshot: ""
            )
        } set: { updatedStep in
            guard let index = model.steps.firstIndex(where: { $0.id == stepID }) else { return }
            model.steps[index] = updatedStep
        }
    }

    private func categoryName(for categoryID: String?) -> String? {
        guard let category = catalogService.catalog.categories.first(where: { $0.id == categoryID }) else {
            return nil
        }
        return categoryName(category)
    }

    private func categoryName(_ category: StepBackCore.WorkoutCategory) -> String {
        catalogService.localizedString(for: category.nameKey)
    }

    private func showPicker() {
        pickerIsPresented = true
    }

    private func hidePicker() {
        pickerIsPresented = false
        model.resetPicker()
    }

    private func commitPickerSelection() {
        let selectedItems = model.pickerSelectionIDs.compactMap { workoutItemsByID[$0] }
        let firstNewStepID = model.addWorkouts(selectedItems)
        pickerIsPresented = false
        if let firstNewStepID {
            scrollTargetStepID = firstNewStepID
        }
    }

    private func cancel() {
        if model.isDirty {
            discardIsPresented = true
        } else {
            dismiss()
        }
    }

    private func save() {
        do {
            let routine = try model.save(existing: existingRoutine, in: modelContext)
            saveFeedback += 1
            onSave(routine)
            dismiss()
        } catch {
            errorIsPresented = true
        }
    }
}

private extension View {
    @ViewBuilder
    func routineNameInputStyle() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    @ViewBuilder
    func routineBuilderListStyle() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        listStyle(.plain)
        #endif
    }
}
