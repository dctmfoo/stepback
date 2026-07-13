import SwiftData
import SwiftUI

struct CustomWorkoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutCatalogService.self) private var catalogService
    @State private var name: String
    @State private var categoryID: String
    @State private var notes: String
    @State private var saveFeedback = 0
    @State private var deleteIsPresented = false
    @State private var errorIsPresented = false
    let workout: CustomWorkout?
    let onDeleted: () -> Void

    init(
        workout: CustomWorkout?,
        initialCategoryID: String,
        onDeleted: @escaping () -> Void = {}
    ) {
        self.workout = workout
        self.onDeleted = onDeleted
        _name = State(initialValue: workout?.name ?? "")
        _categoryID = State(initialValue: workout?.categoryID ?? initialCategoryID)
        _notes = State(initialValue: workout?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.name) {
                    TextField(L10n.name, text: $name)
                        .accessibilityIdentifier("customEditor.name")
                }

                Section(L10n.category) {
                    ForEach(catalogService.catalog.categories, id: \.id) { category in
                        let style = CategoryStyle.resolve(category.id)
                        Button {
                            categoryID = category.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: style.symbolName)
                                    .foregroundStyle(style.color)
                                    .frame(width: 32, height: 32)
                                    .background(style.softColor, in: .rect(cornerRadius: ShapeRadius.tileSmall))
                                    .accessibilityHidden(true)
                                Text(catalogService.localizedString(for: category.nameKey))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if categoryID == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color("PulseAzure"))
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityIdentifier("customEditor.category.\(category.id)")
                    }
                }

                Section(L10n.notes) {
                    TextField(L10n.notesPlaceholder, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("customEditor.notes")
                }

                if workout != nil {
                    Section {
                        Button(L10n.deleteWorkout, systemImage: "trash", role: .destructive) {
                            deleteIsPresented = true
                        }
                    }
                }
            }
            .navigationTitle(workout == nil ? L10n.newWorkoutTitle : L10n.editWorkoutTitle)
            .inlineNavigationTitleOnMobile()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel, action: dismiss.callAsFunction)
                        .accessibilityIdentifier("customEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save, action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("customEditor.save")
                }
            }
            .sensoryFeedback(.success, trigger: saveFeedback)
            .confirmationDialog(
                L10n.deleteWorkoutTitle(workout?.name ?? name),
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
        }
    }

    private func save() {
        do {
            _ = try WorkoutLibrary.save(
                workout,
                name: name,
                categoryID: categoryID,
                notes: notes,
                in: modelContext
            )
            saveFeedback += 1
            dismiss()
        } catch {
            errorIsPresented = true
        }
    }

    private func deleteWorkout() {
        guard let workout else { return }
        do {
            modelContext.delete(workout)
            try modelContext.saveOrRollback()
            dismiss()
            onDeleted()
        } catch {
            errorIsPresented = true
        }
    }
}
