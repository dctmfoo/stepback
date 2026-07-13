import StepBackCore
import SwiftUI

struct TodayPlanCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let plan: Plan
    let status: WeeklyPlanStatus
    let routine: Routine?
    let nextPlannedText: String?
    let open: () -> Void
    let play: () -> Void
    let repair: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(kicker.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(Color("PulseAzure"))
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            titleBlock
                            Spacer()
                            durationText
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            titleBlock
                            durationText
                        }
                    }
                    if let detailText {
                        Text(detailText)
                            .font(.footnote)
                            .foregroundStyle(PlatformColors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("plans.today.card")

            if !dynamicTypeSize.isAccessibilitySize {
                WeeklyPlanStrip(status: status)
            } else {
                Text(stripSummary)
                    .font(.footnote)
                    .foregroundStyle(PlatformColors.secondaryText)
            }

            if canPlay {
                Button(L10n.play, systemImage: "play.fill", action: play)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(L10n.play)
                    .accessibilityIdentifier("plans.today.play")
            } else if needsEditing {
                Button(L10n.plansTodayRepair, systemImage: "wrench", action: repair)
                    .accessibilityIdentifier("plans.today.repair")
            }
        }
        .padding(16)
        .background(PlatformColors.groupedSurface)
        .clipShape(.rect(cornerRadius: ShapeRadius.cardProminent))
    }

    private var kicker: String {
        let weekday = DisplayFormatters.weekday(status.today.weekday, style: .full)
        return "\(L10n.plansTodayKicker) · \(weekday)"
    }

    @ViewBuilder
    private var titleBlock: some View {
        HStack(spacing: 10) {
            if status.today.isRest {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color("RecoverMint"))
                    .frame(width: 36, height: 36)
                    .background(Color("RecoverMintSoft"), in: .rect(cornerRadius: ShapeRadius.insetRow))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title2.bold())
        }
    }

    @ViewBuilder
    private var durationText: some View {
        if let routine, status.today.nextSlot != nil {
            Text(DisplayFormatters.duration(
                TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
            ))
            .font(.title.bold())
            .fontDesign(.rounded)
            .monospacedDigit()
        }
    }

    private var title: String {
        if status.today.isRest { return L10n.plansTodayRestTitle }
        if status.today.isDone { return L10n.plansTodayDoneTitle }
        return status.today.nextSlot?.routineNameSnapshot ?? L10n.plansTodayRestTitle
    }

    private var detailText: String? {
        if status.today.isRest { return nextPlannedText }
        if status.today.isDone { return status.today.slots.last?.routineNameSnapshot }
        if status.today.totalSlotCount > 1 {
            return L10n.plansTodayMultiCount(
                status.today.completedSlotCount,
                status.today.totalSlotCount
            )
        }
        if needsRepair { return L10n.plansRoutineRemoved }
        return nil
    }

    private var stripSummary: String {
        L10n.plansTodayStripAccessibility(status.completedDayCount, status.plannedDayCount)
    }

    private var accessibilitySummary: String {
        var parts = [kicker, title]
        if let routine, status.today.nextSlot != nil {
            parts.append(DisplayFormatters.spokenDuration(
                TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0)
            ))
        }
        if let detailText {
            parts.append(detailText)
        }
        parts.append(stripSummary)
        return parts.joined(separator: L10n.summarySeparator)
    }

    private var needsRepair: Bool {
        status.today.nextSlot != nil && routine == nil
    }

    private var needsEditing: Bool {
        needsRepair || status.plannedDayCount == 0
    }

    private var canPlay: Bool {
        status.today.nextSlot != nil && routine != nil
    }
}

private struct WeeklyPlanStrip: View {
    let status: WeeklyPlanStatus

    var body: some View {
        HStack(spacing: 8) {
            ForEach(status.days, id: \.weekday) { day in
                VStack(spacing: 4) {
                    Text(DisplayFormatters.weekday(day.weekday, style: .initial))
                        .font(.caption)
                    Image(systemName: symbol(for: day))
                        .foregroundStyle(color(for: day))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.plansTodayStripAccessibility(
            status.completedDayCount,
            status.plannedDayCount
        ))
    }

    private func symbol(for day: WeeklyPlanDayStatus) -> String {
        if day.isDone { return "checkmark.circle.fill" }
        if day.weekday == status.today.weekday { return "circle.circle" }
        return day.isRest ? "circle.dotted" : "circle"
    }

    private func color(for day: WeeklyPlanDayStatus) -> Color {
        if day.isDone || day.weekday == status.today.weekday { return Color("PulseAzure") }
        return .secondary
    }
}
