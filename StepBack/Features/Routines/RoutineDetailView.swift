import StepBackCore
import SwiftData
import SwiftUI

struct RoutineDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerLauncher) private var playerLauncher
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var sessions: [RoutineSession]
    @Query private var customWorkouts: [CustomWorkout]
    @State private var builderPresentation: RoutineBuilderPresentation?
    @State private var deleteIsPresented = false
    @State private var errorIsPresented = false
    let routine: Routine

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                hero

                if orderedSteps.isEmpty {
                    ContentUnavailableView(
                        L10n.noStepsTitle,
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text(L10n.noStepsMessage)
                    )
                } else {
                    steps
                }

                actions
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(routine.name)
        .inlineNavigationTitleOnMobile()
        .sheet(item: $builderPresentation) { presentation in
            RoutineBuilderView(
                title: L10n.builderTitleEdit,
                model: presentation.model,
                existingRoutine: presentation.existingRoutine,
                onSave: { _ in }
            )
        }
        .confirmationDialog(
            L10n.deleteRoutineTitle(routine.name),
            isPresented: $deleteIsPresented
        ) {
            Button(L10n.deleteRoutine, role: .destructive, action: deleteRoutine)
        } message: {
            Text(L10n.deleteRoutineMessage)
        }
        .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
            Button(L10n.dismiss, role: .cancel) {}
        } message: {
            Text(L10n.errorMessage)
        }
        .background(PlatformColors.groupedBackground.ignoresSafeArea())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DisplayFormatters.duration(totalSeconds))
                .font(.title.bold())
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel(DisplayFormatters.spokenDuration(totalSeconds))
                .accessibilityValue(heroStats)
                .accessibilityIdentifier("routineDetail.hero")
            Text(heroStats)
                .font(.footnote)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("routineDetail.stats")
                .accessibilityHidden(true)
            if routine.lastEditedVia == "agent" {
                Text(L10n.agentProvenance)
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
                    .accessibilityIdentifier("detail.provenance.agent")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var steps: some View {
        LazyVStack(spacing: 8) {
            ForEach(orderedSteps.enumerated(), id: \.element.id) { index, step in
                RoutineStepRow(
                    step: step,
                    index: index,
                    workout: workoutItemsByID[step.workoutID],
                    categoryName: categoryName(for: workoutItemsByID[step.workoutID]?.categoryID)
                )
                if index < orderedSteps.count - 1, step.restAfterSeconds > 0 {
                    RoutineRestRow(seconds: step.restAfterSeconds, index: index)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(L10n.play, systemImage: "play.fill") {
                playerLauncher.play(routine)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("routineDetail.play")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    editButton
                    duplicateButton
                    deleteButton
                }
            } else {
                HStack(spacing: 12) {
                    editButton
                    duplicateButton
                    deleteButton
                }
            }
        }
        .buttonBorderShape(.roundedRectangle)
    }

    private var editButton: some View {
        Button(action: editRoutine) {
            actionLabel(L10n.editRoutine, systemImage: "pencil", iconColor: Color("PulseAzure"))
        }
            .buttonStyle(.bordered)
            .tint(.primary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(L10n.editRoutine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("detail.edit")
    }

    private var duplicateButton: some View {
        Button(action: duplicateRoutine) {
            actionLabel(L10n.duplicate, systemImage: "plus.square.on.square", iconColor: Color("PulseAzure"))
        }
            .buttonStyle(.bordered)
            .tint(.primary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(L10n.duplicate)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("routineDetail.duplicate")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            deleteIsPresented = true
        } label: {
            actionLabel(L10n.deleteRoutine, systemImage: "trash", iconColor: .red)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(L10n.deleteRoutine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("routineDetail.delete")
    }

    private func actionLabel(_ title: String, systemImage: String, iconColor: Color) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
        }
    }

    private var orderedSteps: [RoutineStep] {
        (routine.steps ?? []).sorted {
            if $0.sortIndex == $1.sortIndex { return $0.workoutID < $1.workoutID }
            return $0.sortIndex < $1.sortIndex
        }
    }

    private var totalSeconds: Int {
        TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
    }

    private var stats: PerRoutineStats {
        DerivedStats.perRoutine(sessions: sessions.map(\.snapshot), routineID: routine.id)
    }

    private var heroStats: String {
        let count = L10n.workoutCount(orderedSteps.count)
        guard let lastDone = stats.lastDone else {
            return [count, L10n.notPlayedYet].joined(separator: L10n.summarySeparator)
        }
        return [
            count,
            L10n.lastDone(DisplayFormatters.relativeDate(lastDone), timesCompleted: stats.timesCompleted)
        ].joined(separator: L10n.summarySeparator)
    }

    private var workoutItemsByID: [String: WorkoutItem] {
        Dictionary(
            uniqueKeysWithValues: WorkoutLibrary.allItems(
                catalogService: catalogService,
                customWorkouts: customWorkouts
            ).map { ($0.id, $0) }
        )
    }

    private func categoryName(for categoryID: String?) -> String? {
        guard let category = catalogService.catalog.categories.first(where: { $0.id == categoryID }) else {
            return nil
        }
        return catalogService.localizedString(for: category.nameKey)
    }

    private func editRoutine() {
        builderPresentation = RoutineBuilderPresentation(
            model: RoutineBuilderModel.editing(routine),
            existingRoutine: routine
        )
    }

    private func duplicateRoutine() {
        do {
            _ = try RoutineLibrary.duplicate(
                routine,
                named: L10n.duplicateName(routine.name),
                in: modelContext
            )
        } catch {
            errorIsPresented = true
        }
    }

    private func deleteRoutine() {
        do {
            modelContext.delete(routine)
            try modelContext.saveOrRollback()
            dismiss()
        } catch {
            errorIsPresented = true
        }
    }
}
