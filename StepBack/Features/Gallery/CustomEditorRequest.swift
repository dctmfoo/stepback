import Foundation

struct CustomEditorRequest: Identifiable {
    enum Mode {
        case create(categoryID: String)
        case edit(workoutID: String)
    }

    let id = UUID()
    let mode: Mode
}
