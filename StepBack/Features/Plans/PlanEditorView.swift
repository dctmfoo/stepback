import SwiftUI

struct PlanEditorView: View {
    private struct PickerRequest: Identifiable {
        let id = UUID()
        let weekday: Int
        let slotID: String?
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var model: PlanEditorModel
    @State private var pickerRequest: PickerRequest?
    @State private var errorIsPresented = false
    let existingPlan: Plan?
    let onSave: (Plan) -> Void

    init(
        model: PlanEditorModel,
        existingPlan: Plan? = nil,
        onSave: @escaping (Plan) -> Void
    ) {
        _model = State(initialValue: model)
        self.existingPlan = existingPlan
        self.onSave = onSave
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                Section {
                    TextField(L10n.name, text: $model.name)
                        .accessibilityIdentifier("plans.editor.name")
                } footer: {
                    Text(L10n.plansNudgeMessage)
                }

                ForEach(model.days) { day in
                    Section(DisplayFormatters.weekday(day.weekday, style: .full)) {
                        if day.slots.isEmpty {
                            Text(L10n.plansDayRest)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("plans.editor.day.\(day.weekday).rest")
                        }
                        ForEach(day.slots) { slot in
                            slotRow(slot, weekday: day.weekday)
                        }
                        .onMove { offsets, destination in
                            model.moveSlots(onWeekday: day.weekday, from: offsets, to: destination)
                        }
                        .onDelete { offsets in
                            for id in offsets.map({ day.slots[$0].id }) {
                                model.deleteSlot(id)
                            }
                        }

                        Button(L10n.plansEditorAddRoutine, systemImage: "plus") {
                            pickerRequest = PickerRequest(weekday: day.weekday, slotID: nil)
                        }
                        .accessibilityIdentifier("plans.editor.day.\(day.weekday).addRoutine")
                    }
                }
            }
            .accessibilityIdentifier("plans.editor.list")
            .navigationTitle(existingPlan == nil ? L10n.plansNew : L10n.plansEdit)
            .inlineNavigationTitleOnMobile()
            .activeListEditModeOnMobile()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel, action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save, action: save)
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("plans.editor.save")
                        .saveKeyboardShortcutOnMac()
                }
            }
            .sheet(item: $pickerRequest) { request in
                PlanRoutinePicker { routine in
                    if let slotID = request.slotID {
                        model.replaceSlot(slotID, with: routine)
                    } else {
                        model.addRoutine(routine, toWeekday: request.weekday)
                    }
                }
            }
            .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text(L10n.errorMessage)
            }
        }
        .macSheetMinimumSize(width: 520, height: 620)
    }

    private func slotRow(_ slot: PlanDraftSlot, weekday: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.routineNameSnapshot)
                    .foregroundStyle(slot.routine == nil ? .secondary : .primary)
                if slot.routine == nil {
                    Text(L10n.plansRoutineRemoved)
                        .font(.footnote)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.plansDayRoutineAccessibility(
            DisplayFormatters.weekday(weekday, style: .full),
            slot.routineNameSnapshot
        ))
        .accessibilityIdentifier("plans.editor.slot.\(slot.id)")
        .swipeActions(edge: .trailing) {
            Button(L10n.deleteRoutine, role: .destructive) { model.deleteSlot(slot.id) }
        }
        .contextMenu {
            Button(L10n.plansReplaceRoutine, systemImage: "arrow.triangle.2.circlepath") {
                pickerRequest = PickerRequest(weekday: weekday, slotID: slot.id)
            }
            Button(L10n.deleteRoutine, systemImage: "trash", role: .destructive) {
                model.deleteSlot(slot.id)
            }
        }
    }

    private func save() {
        do {
            let plan = try model.save(existing: existingPlan, in: modelContext)
            onSave(plan)
            dismiss()
        } catch {
            errorIsPresented = true
        }
    }
}
