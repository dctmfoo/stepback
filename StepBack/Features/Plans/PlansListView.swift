import SwiftData
import SwiftUI

struct PlansListView: View {
    @Query private var plans: [Plan]
    @State private var editorPresentation: PlanEditorPresentation?
    let openPlan: (Plan) -> Void

    var body: some View {
        List {
            ForEach(PlanLibrary.ordered(plans)) { plan in
                Button { openPlan(plan) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name)
                                .font(.headline)
                            Text(summary(for: plan))
                                .font(.footnote)
                                .foregroundStyle(PlatformColors.secondaryText)
                        }
                        Spacer()
                        if plan.isActive {
                            Text(L10n.plansMyWeekTitle)
                                .font(.footnote)
                                .foregroundStyle(Color("PulseAzure"))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plans.picker.plan.\(plan.id)")
            }
        }
        .accessibilityIdentifier("plans.picker.list")
        .navigationTitle(L10n.plansSectionTitle)
        .inlineNavigationTitleOnMobile()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.plansNew, systemImage: "plus") {
                    editorPresentation = PlanEditorPresentation(
                        model: PlanEditorModel.newPlan(name: L10n.plansDefaultName(plans.count + 1))
                    )
                }
            }
        }
        .sheet(item: $editorPresentation) { presentation in
            PlanEditorView(model: presentation.model, onSave: { _ in })
        }
    }

    private func summary(for plan: Plan) -> String {
        let slots = (plan.slots ?? []).sorted(by: PlanSlot.sortOrder)
        let dayCount = Set(slots.compactMap(\.weekdayLabelIndex)).count
        let names = slots.map(\.routineNameSnapshot)
        let list = names.isEmpty ? L10n.plansDayRest : DisplayFormatters.list(Array(names.prefix(3)))
        return L10n.plansPickerSummary(dayCount, list)
    }
}
