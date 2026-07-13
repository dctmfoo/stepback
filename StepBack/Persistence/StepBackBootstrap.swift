import Foundation
import OSLog
import SwiftData

@MainActor
final class StepBackBootstrap {
    let modelContainer: ModelContainer
    let catalogService: WorkoutCatalogService
    #if os(macOS)
    let agentBridgeService: AgentBridgeService?
    #endif

    init(
        modelContainer: ModelContainer? = nil,
        catalogService: WorkoutCatalogService? = nil,
        flagStore: (any StarterSeedingFlagStore)? = nil,
        inFlightMarkerStore: (any InFlightSessionMarkerStore)? = nil,
        dateProvider: (any SessionDateProviding)? = nil
    ) throws {
        WelcomePreferences.configureForLaunch()
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.arguments.contains("-StepBackUITesting")
        let container: ModelContainer
        if let modelContainer {
            container = modelContainer
        } else if isRunningTests {
            container = try StepBackModelContainer.makeInMemory()
        } else {
            container = try StepBackModelContainer.makeCloudKitBacked()
        }
        let catalog = try catalogService ?? WorkoutCatalogService()
        let resolvedFlagStore: any StarterSeedingFlagStore
        if let flagStore {
            resolvedFlagStore = flagStore
        } else if isRunningTests {
            resolvedFlagStore = TransientStarterSeedingFlagStore()
        } else {
            resolvedFlagStore = UserDefaultsStarterSeedingFlagStore()
        }

        self.modelContainer = container
        self.catalogService = catalog

        _ = try StarterRoutineSeeder.seedIfNeeded(
            in: container.mainContext,
            catalogService: catalog,
            flagStore: resolvedFlagStore
        )
        if isRunningTests,
           ProcessInfo.processInfo.environment["StepBackUIRemovedPlanFixture"] == "1" {
            let weekday = Calendar.autoupdatingCurrent.component(.weekday, from: .now)
            let slot = PlanSlot(
                routineID: "removed-routine",
                routineNameSnapshot: "Removed Routine",
                weekdayLabelIndex: weekday
            )
            container.mainContext.insert(Plan(
                name: "Repair Week",
                isActive: true,
                weeklyScheduleVersion: 1,
                slots: [slot]
            ))
            try container.mainContext.saveOrRollback()
        } else if isRunningTests,
                  ProcessInfo.processInfo.environment["StepBackUIPlannedPlanFixture"] == "1",
                  let routine = try container.mainContext.fetch(FetchDescriptor<Routine>())
                    .first(where: { $0.seedIdentifier == "starter.quick-start" }) {
            let weekday = Calendar.autoupdatingCurrent.component(.weekday, from: .now)
            container.mainContext.insert(Plan(
                name: "Normal Week",
                isActive: true,
                weeklyScheduleVersion: 1,
                slots: [PlanSlot(weekdayLabelIndex: weekday, routine: routine)]
            ))
            try container.mainContext.saveOrRollback()
        }
        try StarterRoutineDeduplicator.removePristineDuplicates(in: container.mainContext)
        try PlanWeeklyScheduleMigrator.migrateIfNeeded(in: container.mainContext)
        let recorder = PlayerSessionRecorder(
            modelContext: container.mainContext,
            markerStore: inFlightMarkerStore ?? UserDefaultsInFlightSessionMarkerStore(),
            dateProvider: dateProvider ?? SystemSessionDateProvider()
        )
        _ = try recorder.reconcileAbandonedRun()

        if isRunningTests,
           ProcessInfo.processInfo.environment["StepBackUIEmptyStore"] == "1" {
            for session in try container.mainContext.fetch(FetchDescriptor<RoutineSession>()) {
                container.mainContext.delete(session)
            }
            for routine in try container.mainContext.fetch(FetchDescriptor<Routine>()) {
                container.mainContext.delete(routine)
            }
            try container.mainContext.saveOrRollback()
        }

        #if os(macOS)
        do {
            let bridgeRoot = try ProcessInfo.processInfo.environment["StepBackUIAgentBridgeRootName"]
                .map { name in
                    try AgentBridgePaths.appDefault().rootURL
                        .deletingLastPathComponent()
                        .appending(path: name, directoryHint: .isDirectory)
                }
            let service = try AgentBridgeService(
                modelContext: container.mainContext,
                catalogService: catalog,
                rootURL: bridgeRoot
            )
            try service.prepare()
            service.startMonitoring()
            agentBridgeService = service
        } catch {
            agentBridgeService = nil
            Logger(subsystem: "com.nags.stepback", category: "AgentBridge")
                .error("Agent bridge failed to start: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    func reconcileStarterRoutines() {
        do {
            try StarterRoutineDeduplicator.removePristineDuplicates(in: modelContainer.mainContext)
        } catch {
            assertionFailure("Starter-routine dedupe failed: \(error.localizedDescription)")
        }
        #if os(macOS)
        do {
            try agentBridgeService?.processPendingCommands()
            try agentBridgeService?.refreshManifest()
        } catch {
            Logger(subsystem: "com.nags.stepback", category: "AgentBridge")
                .error("Agent bridge active-scene refresh failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}

private final class TransientStarterSeedingFlagStore: StarterSeedingFlagStore {
    var hasSeededStarterRoutines = false
}
