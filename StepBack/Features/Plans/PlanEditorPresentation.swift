import Foundation

struct PlanEditorPresentation: Identifiable {
    let id = UUID()
    let model: PlanEditorModel
    let existingPlan: Plan?

    init(model: PlanEditorModel, existingPlan: Plan? = nil) {
        self.model = model
        self.existingPlan = existingPlan
    }
}
