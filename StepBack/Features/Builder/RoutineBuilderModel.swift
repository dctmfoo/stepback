import Foundation
import Observation
import SwiftData
import SwiftUI
import StepBackCore

enum RoutineBuilderSaveError: Error, Equatable {
    case emptyName
    case emptySteps
}

struct RoutineDraftStep: Identifiable {
    let id: String
    var sourceStep: RoutineStep?
    var workoutID: String
    var workoutNameSnapshot: String
    var workSeconds: Int
    var sets: Int
    var setRestSeconds: Int
    var restAfterSeconds: Int
    var repGuidance: Int?

    init(
        id: String = UUID().uuidString,
        sourceStep: RoutineStep? = nil,
        workoutID: String,
        workoutNameSnapshot: String,
        defaults: RoutineStepDefaults = .standard,
        workSeconds: Int? = nil,
        sets: Int? = nil,
        setRestSeconds: Int? = nil,
        restAfterSeconds: Int? = nil,
        repGuidance: Int? = nil
    ) {
        self.id = id
        self.sourceStep = sourceStep
        self.workoutID = workoutID
        self.workoutNameSnapshot = workoutNameSnapshot
        self.workSeconds = workSeconds ?? defaults.workSeconds
        self.sets = sets ?? defaults.sets
        self.setRestSeconds = setRestSeconds ?? defaults.setRestSeconds
        self.restAfterSeconds = restAfterSeconds ?? defaults.restAfterSeconds
        self.repGuidance = repGuidance
    }

    init(step: RoutineStep) {
        self.init(
            sourceStep: step,
            workoutID: step.workoutID,
            workoutNameSnapshot: step.workoutNameSnapshot,
            workSeconds: step.workSeconds,
            sets: step.sets,
            setRestSeconds: step.setRestSeconds,
            restAfterSeconds: step.restAfterSeconds,
            repGuidance: step.repGuidance
        )
    }

    var snapshot: RoutineStepSnapshot {
        RoutineStepSnapshot(
            workoutID: workoutID,
            workoutNameSnapshot: workoutNameSnapshot,
            workSeconds: workSeconds,
            sets: sets,
            setRestSeconds: setRestSeconds,
            restAfterSeconds: restAfterSeconds,
            repGuidance: repGuidance
        )
    }

    var defaultsForNextStep: RoutineStepDefaults {
        RoutineStepDefaults(
            workSeconds: workSeconds,
            sets: sets,
            setRestSeconds: setRestSeconds,
            restAfterSeconds: restAfterSeconds
        )
    }

    func makeRoutineStep(sortIndex: Int, routine: Routine?) -> RoutineStep {
        RoutineStep(
            sortIndex: sortIndex,
            workoutID: workoutID,
            workoutNameSnapshot: workoutNameSnapshot,
            workSeconds: workSeconds,
            sets: sets,
            setRestSeconds: setRestSeconds,
            restAfterSeconds: restAfterSeconds,
            repGuidance: repGuidance,
            routine: routine
        )
    }

    func apply(to step: RoutineStep, sortIndex: Int, routine: Routine?) {
        step.sortIndex = sortIndex
        step.workoutID = workoutID
        step.workoutNameSnapshot = workoutNameSnapshot
        step.workSeconds = workSeconds
        step.sets = sets
        step.setRestSeconds = setRestSeconds
        step.restAfterSeconds = restAfterSeconds
        step.repGuidance = repGuidance
        step.routine = routine
    }
}

@Observable
@MainActor
final class RoutineBuilderModel {
    var name: String
    var steps: [RoutineDraftStep]
    var expandedStepID: RoutineDraftStep.ID?
    var pickerSearchText = ""
    var selectedCategoryID: String?
    var pickerSelectionIDs: [String] = []

    private var initialName: String
    private var initialSnapshots: [RoutineStepSnapshot]

    private init(name: String, steps: [RoutineDraftStep]) {
        self.name = name
        self.steps = steps
        initialName = name
        initialSnapshots = steps.map(\.snapshot)
        expandedStepID = steps.first?.id
    }

    static func newRoutine(name: String, initialWorkout: WorkoutItem? = nil) -> RoutineBuilderModel {
        var steps: [RoutineDraftStep] = []
        if let initialWorkout {
            steps.append(RoutineDraftStep(
                workoutID: initialWorkout.id,
                workoutNameSnapshot: initialWorkout.name
            ))
        }
        return RoutineBuilderModel(name: name, steps: steps)
    }

    static func editing(_ routine: Routine) -> RoutineBuilderModel {
        RoutineBuilderModel(
            name: routine.name,
            steps: sortedSteps(for: routine).map(RoutineDraftStep.init(step:))
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedName.isEmpty && !steps.isEmpty
    }

    var isDirty: Bool {
        name != initialName || steps.map(\.snapshot) != initialSnapshots
    }

    var snapshot: RoutineSnapshot {
        RoutineSnapshot(name: trimmedName, steps: steps.map(\.snapshot))
    }

    var totalSeconds: Int {
        TimelineCompiler.totalDurationSeconds(snapshot, getReadySeconds: 0)
    }

    @discardableResult
    func addWorkouts(_ workouts: [WorkoutItem]) -> RoutineDraftStep.ID? {
        guard !workouts.isEmpty else { return nil }
        let defaults = steps.last?.defaultsForNextStep ?? .standard
        let newSteps = workouts.map { workout in
            RoutineDraftStep(
                workoutID: workout.id,
                workoutNameSnapshot: workout.name,
                defaults: defaults,
                repGuidance: nil
            )
        }
        steps.append(contentsOf: newSteps)
        expandedStepID = newSteps.first?.id
        resetPicker()
        return newSteps.first?.id
    }

    func toggleExpandedStep(id: RoutineDraftStep.ID) {
        expandedStepID = expandedStepID == id ? nil : id
    }

    func moveSteps(from offsets: IndexSet, to destination: Int) {
        guard !offsets.isEmpty else { return }
        steps.move(fromOffsets: offsets, toOffset: destination)
        expandedStepID = nil
    }

    func moveStep(id sourceID: RoutineDraftStep.ID, before targetID: RoutineDraftStep.ID) {
        guard sourceID != targetID,
              let sourceIndex = steps.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = steps.firstIndex(where: { $0.id == targetID }) else {
            return
        }
        moveSteps(from: IndexSet(integer: sourceIndex), to: targetIndex)
    }

    func moveStepToEnd(id sourceID: RoutineDraftStep.ID) {
        guard let sourceIndex = steps.firstIndex(where: { $0.id == sourceID }) else { return }
        moveSteps(from: IndexSet(integer: sourceIndex), to: steps.endIndex)
    }

    func moveStepUp(id sourceID: RoutineDraftStep.ID) {
        guard let sourceIndex = steps.firstIndex(where: { $0.id == sourceID }),
              sourceIndex > steps.startIndex else {
            return
        }
        moveSteps(from: IndexSet(integer: sourceIndex), to: sourceIndex - 1)
    }

    func moveStepDown(id sourceID: RoutineDraftStep.ID) {
        guard let sourceIndex = steps.firstIndex(where: { $0.id == sourceID }),
              sourceIndex < steps.index(before: steps.endIndex) else {
            return
        }
        moveSteps(from: IndexSet(integer: sourceIndex), to: sourceIndex + 2)
    }

    func deleteStep(id: RoutineDraftStep.ID) {
        steps.removeAll { $0.id == id }
        if expandedStepID == id {
            expandedStepID = steps.first?.id
        }
    }

    func togglePickerSelection(_ workoutID: String) {
        if let index = pickerSelectionIDs.firstIndex(of: workoutID) {
            pickerSelectionIDs.remove(at: index)
        } else {
            pickerSelectionIDs.append(workoutID)
            pickerSearchText = ""
        }
    }

    func resetPicker() {
        pickerSelectionIDs.removeAll()
        pickerSearchText = ""
        selectedCategoryID = nil
    }

    func save(
        existing routine: Routine?,
        in context: ModelContext,
        now: Date = .now,
        makeID: () -> String = { UUID().uuidString }
    ) throws -> Routine {
        guard !trimmedName.isEmpty else { throw RoutineBuilderSaveError.emptyName }
        guard !steps.isEmpty else { throw RoutineBuilderSaveError.emptySteps }

        if let routine {
            try saveExisting(routine, in: context, now: now)
            markClean()
            return routine
        }

        let routine = Routine(
            id: makeID(),
            name: trimmedName,
            createdAt: now,
            updatedAt: now
        )
        let savedSteps = steps.enumerated().map { index, draft in
            draft.makeRoutineStep(sortIndex: index, routine: routine)
        }
        routine.steps = savedSteps
        context.insert(routine)
        try context.saveOrRollback()
        markClean()
        return routine
    }

    private func saveExisting(
        _ routine: Routine,
        in context: ModelContext,
        now: Date
    ) throws {
        let existingSteps = Self.sortedSteps(for: routine)
        let retained = steps.compactMap(\.sourceStep)
        for step in existingSteps where !retained.contains(where: { $0 === step }) {
            context.delete(step)
        }

        let savedSteps = steps.enumerated().map { index, draft in
            if let source = draft.sourceStep {
                draft.apply(to: source, sortIndex: index, routine: routine)
                return source
            }
            let step = draft.makeRoutineStep(sortIndex: index, routine: routine)
            context.insert(step)
            return step
        }

        routine.name = trimmedName
        routine.updatedAt = now
        routine.lastEditedVia = nil
        routine.steps = savedSteps
        try context.saveOrRollback()
    }

    private func markClean() {
        initialName = name
        initialSnapshots = steps.map(\.snapshot)
    }

    private static func sortedSteps(for routine: Routine) -> [RoutineStep] {
        (routine.steps ?? []).sorted {
            if $0.sortIndex == $1.sortIndex {
                return $0.workoutID < $1.workoutID
            }
            return $0.sortIndex < $1.sortIndex
        }
    }
}
