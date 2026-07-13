import Foundation

struct RoutineBuilderPresentation: Identifiable {
    let id = UUID()
    let model: RoutineBuilderModel
    let existingRoutine: Routine?

    init(model: RoutineBuilderModel, existingRoutine: Routine? = nil) {
        self.model = model
        self.existingRoutine = existingRoutine
    }
}
