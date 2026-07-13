import StepBackCore
import SwiftUI

struct WeeklyPlanDayRow: View {
    let weekday: Int
    let slots: [PlanSlot]
    let isDone: Bool
    let isToday: Bool
    let weekdayName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: markerSymbol)
                .foregroundStyle(markerColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayName)
                    .bold(isToday)
                if slots.isEmpty {
                    Text(L10n.plansDayRest)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(slots) { slot in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.routineNameSnapshot)
                            slotDetail(slot)
                        }
                    }
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? L10n.plansDayDoneAccessibility : "")
    }

    @ViewBuilder
    private func slotDetail(_ slot: PlanSlot) -> some View {
        if let routine = slot.routine {
            Text(DisplayFormatters.duration(
                TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
            ))
            .font(.footnote)
            .foregroundStyle(PlatformColors.secondaryText)
        } else {
            Text(L10n.plansRoutineRemoved)
                .font(.footnote)
                .foregroundStyle(PlatformColors.secondaryText)
        }
    }

    private var markerSymbol: String {
        if isDone { return "checkmark.circle.fill" }
        return isToday ? "circle.circle" : "circle"
    }

    private var markerColor: Color {
        isToday || isDone ? Color("PulseAzure") : .secondary
    }
}
