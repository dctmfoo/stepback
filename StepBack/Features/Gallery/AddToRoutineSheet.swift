import StepBackCore
import SwiftData
import SwiftUI

struct AddToRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]
    @State private var builderPresentation: RoutineBuilderPresentation?
    @State private var errorIsPresented = false
    let workout: WorkoutItem
    let onCreatedRoutine: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button(L10n.newRoutineFromWorkout, systemImage: "plus", action: presentBuilder)
                    .accessibilityIdentifier("addToRoutine.newRoutine")

                ForEach(RoutineLibrary.sorted(routines)) { routine in
                    Button {
                        add(to: routine)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                    .foregroundStyle(.primary)
                                Text(routineSummary(routine))
                                    .font(.footnote)
                                    .foregroundStyle(PlatformColors.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color("PulseAzure"))
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityIdentifier("addToRoutine.routine.\(routine.id)")
                }
            }
            .navigationTitle(L10n.addToRoutineTitle)
            .inlineNavigationTitleOnMobile()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel, action: dismiss.callAsFunction)
                }
            }
            .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text(L10n.errorMessage)
            }
            .sheet(item: $builderPresentation) { presentation in
                RoutineBuilderView(
                    title: L10n.builderTitleNew,
                    model: presentation.model,
                    onSave: { routine in
                        onCreatedRoutine(routine.id)
                        dismiss()
                    }
                )
            }
        }
    }

    private func routineSummary(_ routine: Routine) -> String {
        [
            DisplayFormatters.duration(
                TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
            ),
            L10n.workoutCount(routine.steps?.count ?? 0)
        ].joined(separator: L10n.summarySeparator)
    }

    private func add(to routine: Routine) {
        do {
            _ = try RoutineLibrary.append(workout, to: routine, in: modelContext)
            dismiss()
        } catch {
            errorIsPresented = true
        }
    }

    private func presentBuilder() {
        let number = RoutineLibrary.nextAvailableRoutineNumber(in: routines)
        builderPresentation = RoutineBuilderPresentation(
            model: RoutineBuilderModel.newRoutine(
                name: L10n.defaultRoutineName(number),
                initialWorkout: workout
            )
        )
    }
}
