import StepBackCore
import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [Plan]
    @Query private var sessions: [RoutineSession]
    @State private var editorPresentation: PlanEditorPresentation?
    @State private var deleteIsPresented = false
    @State private var errorIsPresented = false
    let plan: Plan
    let openPicker: () -> Void

    init(plan: Plan, openPicker: @escaping () -> Void = {}) {
        self.plan = plan
        self.openPicker = openPicker
    }

    var body: some View {
        List {
            Section {
                if plan.isActive {
                    Label(L10n.plansMyWeekTitle, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color("PulseAzure"))
                } else {
                    Button(L10n.plansMyWeekSet, systemImage: "checkmark.circle", action: setMyWeek)
                        .accessibilityIdentifier("plans.myWeek.set")
                }
                if plan.lastEditedVia == "agent" {
                    Text(L10n.agentProvenance)
                        .font(.footnote)
                        .foregroundStyle(PlatformColors.secondaryText)
                        .accessibilityIdentifier("detail.provenance.agent")
                }
            }

            Section {
                ForEach(status.days, id: \.weekday) { day in
                    WeeklyPlanDayRow(
                        weekday: day.weekday,
                        slots: planSlots(on: day.weekday),
                        isDone: day.isDone,
                        isToday: day.weekday == status.today.weekday,
                        weekdayName: DisplayFormatters.weekday(day.weekday, style: .full)
                    )
                    .accessibilityIdentifier("plans.overview.day.\(day.weekday)")
                }
            }
            .accessibilityIdentifier("plans.overview.list")

            Section {
                if plans.count > 1 {
                    Button(L10n.plansSectionTitle, systemImage: "rectangle.stack", action: openPicker)
                }
                Button(L10n.plansEditorDuplicatePlan, systemImage: "plus.square.on.square", action: duplicate)
                Button(L10n.plansDelete, systemImage: "trash", role: .destructive) {
                    deleteIsPresented = true
                }
            }
        }
        .navigationTitle(plan.name)
        .inlineNavigationTitleOnMobile()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.plansEdit, systemImage: "pencil") {
                    editorPresentation = PlanEditorPresentation(
                        model: PlanEditorModel.editing(plan),
                        existingPlan: plan
                    )
                }
            }
        }
        .sheet(item: $editorPresentation) { presentation in
            PlanEditorView(
                model: presentation.model,
                existingPlan: presentation.existingPlan,
                onSave: { _ in }
            )
        }
        .confirmationDialog(L10n.plansDeleteConfirmTitle, isPresented: $deleteIsPresented) {
            Button(L10n.plansDelete, role: .destructive, action: deletePlan)
        }
        .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
            Button(L10n.dismiss, role: .cancel) {}
        } message: {
            Text(L10n.errorMessage)
        }
    }

    private var status: WeeklyPlanStatus {
        PlanLibrary.status(for: plan, sessions: sessions)
    }

    private func planSlots(on weekday: Int) -> [PlanSlot] {
        (plan.slots ?? [])
            .filter { $0.weekdayLabelIndex == weekday }
            .sorted(by: PlanSlot.sortOrder)
    }

    private func setMyWeek() {
        perform { try PlanLibrary.setMyWeek(plan, among: plans, in: modelContext) }
    }

    private func duplicate() {
        perform {
            _ = try PlanLibrary.duplicate(
                plan,
                named: L10n.duplicateName(plan.name),
                in: modelContext
            )
        }
    }

    private func deletePlan() {
        perform {
            try PlanLibrary.delete(plan, in: modelContext)
            dismiss()
        }
    }

    private func perform(_ work: () throws -> Void) {
        do { try work() } catch { errorIsPresented = true }
    }
}
