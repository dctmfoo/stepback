import SwiftData
import SwiftUI

struct PlanRoutinePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var routines: [Routine]
    let select: (Routine) -> Void

    var body: some View {
        NavigationStack {
            List(RoutineLibrary.sorted(routines)) { routine in
                Button {
                    select(routine)
                    dismiss()
                } label: {
                    Label(routine.name, systemImage: "rectangle.stack")
                        .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("plans.picker.routine.\(routine.id)")
            }
            .navigationTitle(L10n.plansEditorAddRoutine)
            .inlineNavigationTitleOnMobile()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .macSheetMinimumSize(width: 420, height: 520)
    }
}
