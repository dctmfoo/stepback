import StepBackCore
import SwiftData
import SwiftUI

private enum RoutinesHomeRoute: Hashable {
    case routine(String)
    case plan(String)
    case plans
}

struct RoutinesHomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerLauncher) private var playerLauncher
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var routines: [Routine]
    @Query private var sessions: [RoutineSession]
    @Query private var customWorkouts: [CustomWorkout]
    @Query private var plans: [Plan]
    @State private var path: [RoutinesHomeRoute] = []
    @State private var pendingDelete: Routine?
    @State private var builderPresentation: RoutineBuilderPresentation?
    @State private var planEditorPresentation: PlanEditorPresentation?
    @State private var errorIsPresented = false
    private let selectRoutine: ((String) -> Void)?

    init(selectRoutine: ((String) -> Void)? = nil) {
        self.selectRoutine = selectRoutine
    }

    var body: some View {
        NavigationStack(path: $path) {
            homeContent
            .navigationTitle(L10n.tabRoutines)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.newRoutine, systemImage: "plus", action: createRoutine)
                        .accessibilityIdentifier("home.newRoutine")
                }
            }
            .navigationDestination(for: RoutinesHomeRoute.self) { route in
                switch route {
                case let .routine(id):
                    if let routine = routines.first(where: { $0.id == id }) {
                        RoutineDetailView(routine: routine)
                    } else {
                        ContentUnavailableView(L10n.noRoutinesTitle, systemImage: "figure.run")
                    }
                case let .plan(id):
                    if let plan = plans.first(where: { $0.id == id }) {
                        PlanDetailView(plan: plan, openPicker: { path.append(.plans) })
                    } else {
                        ContentUnavailableView(L10n.plansMyWeekChoose, systemImage: "calendar")
                    }
                case .plans:
                    PlansListView(openPlan: openPlan)
                }
            }
            .sheet(item: $builderPresentation) { presentation in
                RoutineBuilderView(
                    title: L10n.builderTitleNew,
                    model: presentation.model,
                    onSave: openRoutine
                )
            }
            .sheet(item: $planEditorPresentation) { presentation in
                PlanEditorView(
                    model: presentation.model,
                    existingPlan: presentation.existingPlan,
                    onSave: openPlan
                )
            }
            .confirmationDialog(
                pendingDelete.map { L10n.deleteRoutineTitle($0.name) } ?? L10n.deleteRoutine,
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { routine in
                Button(L10n.deleteRoutine, role: .destructive) {
                    delete(routine)
                }
            } message: { _ in
                Text(L10n.deleteRoutineMessage)
            }
            .alert(L10n.errorTitle, isPresented: $errorIsPresented) {
                Button(L10n.dismiss, role: .cancel) {}
            } message: {
                Text(L10n.errorMessage)
            }
            .task(id: activePlanIDs) {
                do {
                    try PlanLibrary.reconcileExclusiveSelection(plans, in: modelContext)
                } catch {
                    errorIsPresented = true
                }
            }
            .background(PlatformColors.groupedBackground.ignoresSafeArea())
        }
    }

    private var homeContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let myWeekPlan {
                    todaySurface(myWeekPlan)
                }

                if RoutineLibrary.shouldShowMotivation(sessions: sessions) {
                    MotivationStrip(sessions: sessionSnapshots, now: .now)
                }

                if orderedRoutines.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(orderedRoutines) { routine in
                            RoutineCard(
                                routine: routine,
                                sessionSnapshots: sessionSnapshots,
                                categoryIDs: categoryIDs(for: routine),
                                open: { openRoutine(routine) },
                                play: { playerLauncher.play(routine) },
                                duplicate: { duplicate(routine) },
                                delete: { pendingDelete = routine }
                            )
                        }
                    }
                }

                planManagementRow
            }
            .padding(horizontalSizeClass == .compact ? 16 : 24)
        }
        .accessibilityIdentifier("home.scroll")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L10n.noRoutinesTitle, systemImage: "figure.run")
        } description: {
            Text(L10n.noRoutinesMessage)
        } actions: {
            Button(L10n.newRoutine, systemImage: "plus", action: createRoutine)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("home.empty.newRoutine")
            Button(L10n.restoreStarters, action: restoreStarters)
                .accessibilityIdentifier("home.empty.restore")
        }
    }

    private var orderedRoutines: [Routine] {
        RoutineLibrary.sorted(routines)
    }

    private var orderedPlans: [Plan] { PlanLibrary.ordered(plans) }
    private var myWeekPlan: Plan? { orderedPlans.first(where: \.isActive) }
    private var activePlanIDs: [String] { plans.filter(\.isActive).map(\.id).sorted() }

    private var sessionSnapshots: [SessionSnapshot] {
        sessions.map(\.snapshot)
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            [GridItem(.flexible())]
        } else {
            [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16)]
        }
    }

    private var workoutItemsByID: [String: WorkoutItem] {
        Dictionary(
            uniqueKeysWithValues: WorkoutLibrary.allItems(
                catalogService: catalogService,
                customWorkouts: customWorkouts
            ).map { ($0.id, $0) }
        )
    }

    private func categoryIDs(for routine: Routine) -> [String] {
        let present = Set((routine.steps ?? []).compactMap { workoutItemsByID[$0.workoutID]?.categoryID })
        return catalogService.catalog.categories.map(\.id).filter(present.contains)
    }

    private func createRoutine() {
        let number = RoutineLibrary.nextAvailableRoutineNumber(in: routines)
        builderPresentation = RoutineBuilderPresentation(
            model: RoutineBuilderModel.newRoutine(
                name: L10n.defaultRoutineName(number)
            )
        )
    }

    private func openRoutine(_ routine: Routine) {
        if let selectRoutine {
            selectRoutine(routine.id)
        } else {
            path.append(.routine(routine.id))
        }
    }

    private func todaySurface(_ plan: Plan) -> some View {
        let status = PlanLibrary.status(for: plan, sessions: sessions)
        let routine = status.today.nextSlot.flatMap { slot in
            routines.first(where: { $0.id == slot.routineID })
        }
        return TodayPlanCard(
            plan: plan,
            status: status,
            routine: routine,
            nextPlannedText: nextPlannedText(in: status),
            open: { openPlan(plan) },
            play: {
                guard let routine else { return }
                playerLauncher.play(routine, planContext: PlanLibrary.launchContext(for: plan))
            },
            repair: {
                planEditorPresentation = PlanEditorPresentation(
                    model: PlanEditorModel.editing(plan),
                    existingPlan: plan
                )
            }
        )
    }

    private func createPlan() {
        planEditorPresentation = PlanEditorPresentation(
            model: PlanEditorModel.newPlan(name: L10n.plansDefaultName(plans.count + 1))
        )
    }

    private func openPlan(_ plan: Plan) {
        path.append(.plan(plan.id))
    }

    @ViewBuilder
    private var planManagementRow: some View {
        if let myWeekPlan {
            Button { openPlan(myWeekPlan) } label: {
                Label(L10n.plansMyWeekRow(myWeekPlan.name), systemImage: "calendar")
                    .planManagementSurface()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans.myWeek.row")
        } else if plans.isEmpty {
            Button(action: createPlan) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.plansNudgeTitle, systemImage: "calendar.badge.plus")
                    Text(L10n.plansNudgeMessage)
                        .font(.footnote)
                        .foregroundStyle(PlatformColors.secondaryText)
                }
                .planManagementSurface()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel([
                L10n.plansNudgeTitle,
                L10n.plansNudgeMessage,
            ].joined(separator: L10n.summarySeparator))
            .accessibilityIdentifier("plans.nudge.row")
        } else {
            Button { path.append(.plans) } label: {
                Label(L10n.plansMyWeekChoose, systemImage: "calendar")
                    .planManagementSurface()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plans.myWeek.row")
        }
    }

    private func nextPlannedText(in status: WeeklyPlanStatus) -> String? {
        guard status.today.isRest,
              let todayIndex = status.days.firstIndex(where: { $0.weekday == status.today.weekday }) else {
            return nil
        }
        let laterDays = status.days.dropFirst(todayIndex + 1)
        let earlierDays = status.days.prefix(todayIndex + 1)
        let following = Array(laterDays) + Array(earlierDays)
        guard let day = following.first(where: { !$0.slots.isEmpty }), let slot = day.slots.first else {
            return nil
        }
        return L10n.plansTodayNext(
            DisplayFormatters.weekday(day.weekday, style: .full),
            slot.routineNameSnapshot
        )
    }

    private func restoreStarters() {
        do {
            _ = try StarterRoutineSeeder.restoreMissing(
                in: modelContext,
                catalogService: catalogService
            )
        } catch {
            errorIsPresented = true
        }
    }

    private func duplicate(_ routine: Routine) {
        do {
            _ = try RoutineLibrary.duplicate(
                routine,
                named: L10n.duplicateName(routine.name),
                in: modelContext
            )
        } catch {
            errorIsPresented = true
        }
    }

    private func delete(_ routine: Routine) {
        do {
            modelContext.delete(routine)
            try modelContext.saveOrRollback()
            pendingDelete = nil
        } catch {
            errorIsPresented = true
        }
    }
}

private extension View {
    func planManagementSurface() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                PlatformColors.groupedSurface,
                in: .rect(cornerRadius: ShapeRadius.card)
            )
    }
}
