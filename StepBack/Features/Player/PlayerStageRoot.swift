import AVFAudio
import StepBackCore
import SwiftData
import SwiftUI

struct PlayerStageRoot: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WorkoutCatalogService.self) private var catalogService
    @Query private var customWorkouts: [CustomWorkout]
    @State private var model: PlayerSessionModel
    @State private var endConfirmationIsPresented = false
    @State private var completionStats: PlayerCompletionStats?
    @State private var sessionRecorder: PlayerSessionRecorder?
    @State private var wakeService = PlayerWakeService()
    private let routine: Routine
    private let planContext: PlanLaunchContext?
    private let dismiss: () -> Void
    private let signposts: any PlayerSignposting

    init(
        routine: Routine,
        planContext: PlanLaunchContext? = nil,
        signposts: any PlayerSignposting = NoopPlayerSignposter(),
        dismiss: @escaping () -> Void
    ) {
        self.routine = routine
        self.planContext = planContext
        self.dismiss = dismiss
        self.signposts = signposts
        _model = State(initialValue: PlayerSessionModel(routine: routine, signposts: signposts))
    }

    var body: some View {
        stageContent
            .background(Color("StageCanvas").ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.stage")
            .onAppear {
                signposts.endPlayToPreRoll()
                beginRecording()
                wakeService.enable()
                model.start()
            }
            .onDisappear {
                signposts.endSegment()
                recordWindowCloseIfNeeded()
                wakeService.disable()
            }
            .onChange(of: model.snapshot.currentSegmentIndex) { _, _ in
                checkpoint()
            }
            .onChange(of: model.snapshot.status) { _, status in
                if status == .paused {
                    checkpoint()
                }
            }
            .onChange(of: model.phase) { _, phase in
                handlePhase(phase)
                if phase != .playing {
                    wakeService.disable()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                #if os(iOS)
                if phase != .active {
                    checkpoint()
                    model.pause()
                    wakeService.disable()
                } else if model.phase == .playing {
                    wakeService.enable()
                }
                #endif
            }
            .confirmationDialog(
                L10n.playerEndConfirmTitle,
                isPresented: $endConfirmationIsPresented
            ) {
                Button(L10n.playerEndConfirm, role: .destructive, action: endEarly)
                    .accessibilityIdentifier("player.end.confirm")
                Button(L10n.playerEndKeep, role: .cancel) {}
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .began,
                      note.userInfo?["AVAudioSessionInterruptionWasSuspendedKey"] as? Bool != true else { return }
                model.pause()
            }
            #endif
    }

    @ViewBuilder
    private var stageContent: some View {
        switch model.phase {
        case .playing:
            PlayerStageView(
                model: model,
                workout: currentWorkout,
                categoryName: categoryName,
                end: { endConfirmationIsPresented = true }
            )
        case .completed:
            PlayerCompletionView(
                model: model,
                stats: completionStats,
                done: dismiss,
                goAgain: restart
            )
        case .partial:
            PlayerPartialCompletionView(model: model, done: dismiss)
        }
    }

    private var currentWorkout: WorkoutItem? {
        guard let id = model.currentSegment?.step?.workoutID else { return nil }
        return workoutItems[id]
    }

    private var workoutItems: [String: WorkoutItem] {
        Dictionary(uniqueKeysWithValues: WorkoutLibrary.allItems(
            catalogService: catalogService,
            customWorkouts: customWorkouts
        ).map { ($0.id, $0) })
    }

    private var categoryName: String? {
        guard let categoryID = currentWorkout?.categoryID,
              let category = catalogService.catalog.categories.first(where: { $0.id == categoryID }) else {
            return nil
        }
        return catalogService.localizedString(for: category.nameKey)
    }

    private func restart() {
        model = PlayerSessionModel(routine: routine, signposts: signposts)
        completionStats = nil
        beginRecording()
        wakeService.enable()
        model.start()
    }

    private func beginRecording() {
        let recorder = sessionRecorder ?? PlayerSessionRecorder(modelContext: modelContext)
        do {
            try recorder.begin(
                routine: routine,
                totalStepCount: model.summary.totalStepCount,
                planContext: planContext
            )
            sessionRecorder = recorder
        } catch {
            assertionFailure("Session recovery marker could not start: \(error.localizedDescription)")
        }
    }

    private func checkpoint() {
        do {
            try sessionRecorder?.checkpoint(model.summary)
        } catch {
            assertionFailure("Session checkpoint failed: \(error.localizedDescription)")
        }
    }

    private func handlePhase(_ phase: PlayerSessionModel.Phase) {
        switch phase {
        case .playing:
            return
        case .completed:
            guard recordCurrentRun() != nil else { return }
            completionStats = currentCompletionStats()
        case .partial:
            if recordCurrentRun() == nil {
                dismiss()
            }
        }
    }

    private func recordWindowCloseIfNeeded() {
        guard model.phase == .playing else { return }
        _ = recordCurrentRun()
    }

    @discardableResult
    private func recordCurrentRun() -> RoutineSession? {
        do {
            return try sessionRecorder?.finish(model.summary)
        } catch {
            assertionFailure("Session recording failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func endEarly() {
        if model.summary.activeSeconds == 0, model.summary.completedStepCount == 0 {
            sessionRecorder?.discard()
            model.endEarly()
            dismiss()
        } else {
            model.endEarly()
        }
    }

    private func currentCompletionStats() -> PlayerCompletionStats? {
        do {
            let sessions = try modelContext.fetch(FetchDescriptor<RoutineSession>()).map(\.snapshot)
            let routineStats = DerivedStats.perRoutine(sessions: sessions, routineID: routine.id)
            return PlayerCompletionStats(
                streak: DerivedStats.currentStreak(sessions: sessions, calendar: calendar, now: .now),
                timesCompleted: routineStats.timesCompleted
            )
        } catch {
            assertionFailure("Completion stats could not load: \(error.localizedDescription)")
            return nil
        }
    }
}
