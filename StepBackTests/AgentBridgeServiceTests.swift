import Foundation
import SwiftData
import Testing
@testable import StepBack

@Suite("Agent bridge app service")
@MainActor
struct AgentBridgeServiceTests {
    @Test("Ordered commands create a routine and plan, activate it, and regenerate the manifest")
    func orderedCreatePlanActivationFlow() throws {
        let harness = try Harness()
        let routineCommandID = "11111111-1111-4111-8111-111111111111"
        let planCommandID = "22222222-2222-4222-8222-222222222222"
        let activationCommandID = "33333333-3333-4333-8333-333333333333"

        try harness.drop("001-routine.json", commandID: routineCommandID, verb: "createRoutine", payload: """
        {"name":"Agent Core","steps":[{"workoutID":"bridge","workSeconds":30,"sets":3,"setRestSeconds":10,"restAfterSeconds":15}]}
        """)
        try harness.drop(
            "002-plan.json",
            commandID: planCommandID,
            verb: "createPlan",
            payload: planPayload(name: "Generated Split", routineReference: routineCommandID)
        )
        try harness.service.processPendingCommands()

        let routine = try #require(harness.fetch(Routine.self).first { $0.name == "Agent Core" })
        let plan = try #require(harness.fetch(Plan.self).first { $0.name == "Generated Split" })
        #expect(plan.slots?.first?.routineID == routine.id)
        #expect(routine.id == routineCommandID)
        #expect(plan.id == planCommandID)
        #expect(routine.lastEditedVia == "agent")
        #expect(plan.lastEditedVia == "agent")

        try harness.drop(
            "003-activate.json",
            commandID: activationCommandID,
            verb: "activatePlan",
            expectedUpdatedAt: AgentBridgeDateCoding.string(from: plan.updatedAt),
            payload: """
            {"id":"\(plan.id)"}
            """
        )
        try harness.service.processPendingCommands()
        #expect(plan.isActive)

        let manifest = try harness.readManifest()
        #expect(manifest.routines.contains { $0.id == routine.id && $0.totalSeconds == 110 })
        #expect(manifest.plans.contains { $0.id == plan.id && $0.isMyWeek })
        #expect(try harness.outcome(commandID: routineCommandID).status == .success)
        #expect(try harness.outcome(commandID: planCommandID).resultingIDs["plan"] == plan.id)
        #expect(try harness.pendingFiles().isEmpty)
    }

    @Test("Manifest reports only the latest completed session as routine recency")
    func manifestRoutineRecency() throws {
        let harness = try Harness()
        let routine = Routine(id: "routine-recency", name: "Recovery Flow", createdAt: .now)
        let olderCompletion = Date(timeIntervalSince1970: 1_700_000_000)
        let latestCompletion = Date(timeIntervalSince1970: 1_700_086_400)
        routine.sessions = [
            RoutineSession(
                routineNameSnapshot: routine.name,
                startedAt: olderCompletion.addingTimeInterval(-600),
                endedAt: olderCompletion,
                wasCompleted: true,
                routine: routine
            ),
            RoutineSession(
                routineNameSnapshot: routine.name,
                startedAt: latestCompletion.addingTimeInterval(-300),
                endedAt: latestCompletion,
                wasCompleted: true,
                routine: routine
            ),
            RoutineSession(
                routineNameSnapshot: routine.name,
                startedAt: latestCompletion.addingTimeInterval(3_600),
                endedAt: latestCompletion.addingTimeInterval(4_200),
                wasCompleted: false,
                routine: routine
            ),
            RoutineSession(
                routineNameSnapshot: routine.name,
                startedAt: latestCompletion.addingTimeInterval(7_200),
                endedAt: nil,
                wasCompleted: true,
                routine: routine
            )
        ]
        harness.context.insert(routine)
        try harness.context.save()

        try harness.service.refreshManifest(force: true)

        let entry = try #require(harness.readManifest().routines.first { $0.id == routine.id })
        #expect(entry.lastCompletedAt == AgentBridgeDateCoding.string(from: latestCompletion))
        #expect(entry.completedSessionCount == 3)
    }

    @Test("Manifest reports null recency for a routine without a completed session")
    func manifestRoutineWithoutCompletion() throws {
        let harness = try Harness()
        let routine = Routine(id: "routine-never-completed", name: "New Routine", createdAt: .now)
        routine.sessions = [
            RoutineSession(
                routineNameSnapshot: routine.name,
                endedAt: .now,
                wasCompleted: false,
                routine: routine
            )
        ]
        harness.context.insert(routine)
        try harness.context.save()

        try harness.service.refreshManifest(force: true)

        let entry = try #require(harness.readManifest().routines.first { $0.id == routine.id })
        #expect(entry.lastCompletedAt == nil)
        let manifestObject = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: harness.service.paths.manifestURL)) as? [String: Any]
        )
        let routines = try #require(manifestObject["routines"] as? [[String: Any]])
        let rawEntry = try #require(routines.first { $0["id"] as? String == routine.id })
        #expect(rawEntry["lastCompletedAt"] is NSNull)
    }

    @Test("Generated manifest v3 validates against the published schema")
    func generatedManifestMatchesSchema() throws {
        let harness = try Harness()
        let completed = Routine(id: "routine-schema-completed", name: "Completed", createdAt: .now)
        completed.sessions = [RoutineSession(endedAt: .now, wasCompleted: true, routine: completed)]
        let neverCompleted = Routine(id: "routine-schema-null", name: "Not Completed", createdAt: .now)
        harness.context.insert(completed)
        harness.context.insert(neverCompleted)
        try harness.context.save()
        try harness.service.refreshManifest(force: true)

        let schemaURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "plugin/schema/manifest.schema.json")
        let schema = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        )
        let manifest = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: harness.service.paths.manifestURL)) as? [String: Any]
        )

        try JSONSchemaTestValidator.validate(instance: manifest, schema: schema)
        #expect(manifest["schemaVersion"] as? Int == 3)

        var invalidManifest = manifest
        var invalidRoutines = try #require(invalidManifest["routines"] as? [[String: Any]])
        invalidRoutines[0]["lastCompletedAt"] = 42
        invalidManifest["routines"] = invalidRoutines
        #expect(throws: JSONSchemaValidationError.self) {
            try JSONSchemaTestValidator.validate(instance: invalidManifest, schema: schema)
        }
    }

    @Test("Create and full replacement updates each authoring object type")
    func createAndUpdateObjects() throws {
        let harness = try Harness()
        let workoutCreate = "44444444-4444-4444-8444-444444444444"
        try harness.drop("001-workout.json", commandID: workoutCreate, verb: "createCustomWorkout", payload: """
        {"name":"Wall Sit","categoryID":"legs-glutes","notes":"Original"}
        """)
        try harness.service.processPendingCommands()
        let workout = try #require(harness.fetch(CustomWorkout.self).first)
        let originalUpdatedAt = workout.updatedAt

        try harness.drop(
            "002-workout-update.json",
            commandID: "55555555-5555-4555-8555-555555555555",
            verb: "updateCustomWorkout",
            expectedUpdatedAt: AgentBridgeDateCoding.string(from: originalUpdatedAt),
            payload: """
            {"id":"\(workout.id)","name":"Wall Sit Hold","categoryID":"legs-glutes","notes":null}
            """
        )
        try harness.service.processPendingCommands()
        #expect(workout.name == "Wall Sit Hold")
        #expect(workout.notes == nil)
        #expect(workout.updatedAt > originalUpdatedAt)
        #expect(workout.lastEditedVia == "agent")
    }

    @Test("Routine and plan updates are full replacements and preserve object identity")
    func fullReplacementUpdates() throws {
        let harness = try Harness()
        let routine = Routine(
            id: "routine-existing",
            name: "Original Routine",
            createdAt: .now,
            steps: [RoutineStep(workoutID: "bridge", workoutNameSnapshot: "Bridge")]
        )
        let plan = Plan(
            id: "plan-existing",
            name: "Original Plan",
            createdAt: .now,
            slots: [PlanSlot(routine: routine)]
        )
        harness.context.insert(routine)
        harness.context.insert(plan)
        try harness.context.save()

        try harness.drop(
            "001-routine-update.json",
            commandID: "D1111111-1111-4111-8111-111111111111",
            verb: "updateRoutine",
            expectedUpdatedAt: AgentBridgeDateCoding.string(from: routine.updatedAt),
            payload: #"{"id":"routine-existing","name":"Empty Recovery","steps":[]}"#
        )
        try harness.drop(
            "002-plan-update.json",
            commandID: "D2222222-2222-4222-8222-222222222222",
            verb: "updatePlan",
            expectedUpdatedAt: AgentBridgeDateCoding.string(from: plan.updatedAt),
            payload: planPayload(name: "Rest Week", id: "plan-existing")
        )
        try harness.service.processPendingCommands()

        #expect(routine.id == "routine-existing")
        #expect(routine.name == "Empty Recovery")
        #expect(routine.steps?.isEmpty == true)
        #expect(plan.id == "plan-existing")
        #expect(plan.name == "Rest Week")
        #expect(!plan.isRepeating)
        #expect(plan.weekCount == 1)
        #expect(plan.weeklyScheduleVersion == 1)
        #expect(plan.slots?.isEmpty == true)
        #expect(routine.lastEditedVia == "agent")
        #expect(plan.lastEditedVia == "agent")
    }

    @Test("Unknown delete verbs fail without mutating the store and later commands still run")
    func deleteRejectionDoesNotInterruptSweep() throws {
        let harness = try Harness()
        try harness.drop(
            "001-delete.json",
            commandID: "66666666-6666-4666-8666-666666666666",
            verb: "deleteRoutine",
            payload: #"{"id":"anything"}"#
        )
        try harness.drop(
            "002-create.json",
            commandID: "77777777-7777-4777-8777-777777777777",
            verb: "createCustomWorkout",
            payload: #"{"name":"Safe","categoryID":"core"}"#
        )

        try harness.service.processPendingCommands()

        #expect(harness.fetch(CustomWorkout.self).map(\.name) == ["Safe"])
        let failed = try harness.outcome(commandID: "66666666-6666-4666-8666-666666666666", failed: true)
        #expect(failed.reason == .unknownVerb)
        #expect(try harness.outcome(commandID: "77777777-7777-4777-8777-777777777777").status == .success)
    }

    @Test("Retired plan deactivation fails with the My Week replacement path")
    func deactivatePlanExplainsReplacement() throws {
        let harness = try Harness()
        let commandID = "68686868-6868-4686-8686-686868686868"
        try harness.drop(
            "001-deactivate.json",
            commandID: commandID,
            verb: "deactivatePlan",
            payload: #"{"id":"plan"}"#
        )

        try harness.service.processPendingCommands()

        let failed = try harness.outcome(commandID: commandID, failed: true)
        #expect(failed.reason == .invalidField)
        #expect(failed.field == "verb.deactivatePlan.use.activatePlan.to.setMyWeek")
    }

    @Test("Duplicate IDs replay the original outcome without double apply")
    func idempotentReplay() throws {
        let harness = try Harness()
        let commandID = "8A888888-8888-4888-8888-888888888888"
        try harness.drop(
            "001-first.json",
            commandID: commandID,
            verb: "createCustomWorkout",
            payload: #"{"name":"First","categoryID":"core"}"#
        )
        try harness.service.processPendingCommands()
        let originalID = try #require(harness.fetch(CustomWorkout.self).first?.id)

        try harness.drop(
            "002-replay.json",
            commandID: commandID.lowercased(),
            verb: "createCustomWorkout",
            payload: #"{"name":"Ignored","categoryID":"core"}"#
        )
        try harness.service.processPendingCommands()

        #expect(harness.fetch(CustomWorkout.self).map(\.name) == ["First"])
        let replay = try harness.outcome(commandID: commandID)
        #expect(replay.resultingIDs["customWorkout"] == originalID)
        #expect(replay.duplicateCommand)
    }

    @Test("Disabled, stale, malformed, and oversized commands fail precisely")
    func failureClasses() throws {
        let harness = try Harness()
        harness.defaults.set(false, forKey: AgentBridgeSettings.allowChangesKey)
        try harness.drop(
            "001-disabled.json",
            commandID: "99999999-9999-4999-8999-999999999999",
            verb: "createCustomWorkout",
            payload: #"{"name":"Nope","categoryID":"core"}"#
        )
        try harness.service.processPendingCommands()
        #expect(try harness.outcome(commandID: "99999999-9999-4999-8999-999999999999", failed: true).reason == .bridgeDisabled)

        harness.defaults.set(true, forKey: AgentBridgeSettings.allowChangesKey)
        let workout = CustomWorkout(name: "Existing", categoryID: "core", createdAt: .now, updatedAt: .now)
        harness.context.insert(workout)
        try harness.context.save()
        try harness.drop(
            "002-stale.json",
            commandID: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
            verb: "updateCustomWorkout",
            expectedUpdatedAt: "2020-01-01T00:00:00.000Z",
            payload: """
            {"id":"\(workout.id)","name":"Changed","categoryID":"core"}
            """
        )
        try Data("not json".utf8).write(to: harness.inbox.appending(path: "003-malformed.json"))
        try Data(repeating: 0x20, count: AgentBridgeProtocol.maxCommandBytes + 1)
            .write(to: harness.inbox.appending(path: "004-oversized.json"))
        try harness.service.processPendingCommands()

        #expect(workout.name == "Existing")
        #expect(try harness.outcome(commandID: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA", failed: true).reason == .staleObject)
        #expect(try harness.failedOutcomes().contains { $0.reason == .invalidJSON })
        #expect(try harness.failedOutcomes().contains { $0.reason == .fileTooLarge })

        let hostileID = "../../escaped"
        try harness.drop(
            "005-hostile.json",
            commandID: hostileID,
            verb: "createCustomWorkout",
            payload: #"{"name":"Unsafe","categoryID":"core"}"#
        )
        try harness.service.processPendingCommands()
        #expect(!FileManager.default.fileExists(atPath: harness.root.deletingLastPathComponent().appending(path: "escaped").path))
        #expect(try harness.failedOutcomes().contains { $0.field == "commandID" })

        try FileManager.default.createDirectory(
            at: harness.inbox.appending(path: "006-unreadable.json"),
            withIntermediateDirectories: false
        )
        try harness.service.processPendingCommands()
        #expect(try harness.failedOutcomes().contains { $0.reason == .invalidJSON })
        #expect(try harness.pendingFiles().isEmpty)
    }

    @Test("A corrupt idempotency log stops ingestion without risking duplicate mutation")
    func corruptProcessedLogFailsClosed() throws {
        let harness = try Harness()
        try Data("corrupt".utf8).write(to: harness.service.paths.processedLogURL)
        try harness.drop(
            "001-create.json",
            commandID: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB",
            verb: "createCustomWorkout",
            payload: #"{"name":"Must Not Apply","categoryID":"core"}"#
        )

        try harness.service.processPendingCommands()

        #expect(harness.fetch(CustomWorkout.self).isEmpty)
        #expect(try harness.pendingFiles().map(\.lastPathComponent) == ["001-create.json"])
    }

    @Test("Create IDs cannot impersonate a human-authored object")
    func createIDCollisionFailsClosed() throws {
        let harness = try Harness()
        let objectID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
        let workout = CustomWorkout(
            id: objectID,
            name: "Human Object",
            categoryID: "core",
            createdAt: .now,
            updatedAt: .now
        )
        harness.context.insert(workout)
        try harness.context.save()
        try harness.drop(
            "001-collision.json",
            commandID: objectID,
            verb: "createCustomWorkout",
            payload: #"{"name":"Agent Impostor","categoryID":"core"}"#
        )

        try harness.service.processPendingCommands()

        #expect(workout.name == "Human Object")
        let outcome = try harness.outcome(commandID: objectID, failed: true)
        #expect(outcome.reason == .invalidField)
        #expect(outcome.field == "commandID")
    }

    private func planPayload(
        name: String,
        id: String? = nil,
        routineReference: String? = nil
    ) -> String {
        let identifier = id.map { "\"id\":\"\($0)\"," } ?? ""
        let slots = routineReference.map {
            #"[{"routineRef":{"fromCommand":"\#($0)"}}]"#
        } ?? "[]"
        return """
        {\(identifier)"name":"\(name)","days":[
          {"weekday":1,"slots":\(slots)},
          {"weekday":2,"slots":[]},
          {"weekday":3,"slots":[]},
          {"weekday":4,"slots":[]},
          {"weekday":5,"slots":[]},
          {"weekday":6,"slots":[]},
          {"weekday":7,"slots":[]}
        ]}
        """
    }
}

@MainActor
private final class Harness {
    let root: URL
    let inbox: URL
    let container: ModelContainer
    let context: ModelContext
    let defaults: UserDefaults
    let service: AgentBridgeService

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "StepBackAgentBridgeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        inbox = root.appending(path: "inbox", directoryHint: .isDirectory)
        container = try PersistenceTestSupport.makeContainer()
        context = container.mainContext
        defaults = UserDefaults(suiteName: "StepBackAgentBridgeTests.\(UUID().uuidString)")!
        defaults.set(true, forKey: AgentBridgeSettings.allowChangesKey)
        service = try AgentBridgeService(
            modelContext: context,
            catalogService: WorkoutCatalogService(),
            rootURL: root,
            defaults: defaults
        )
        try service.prepare()
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func drop(
        _ filename: String,
        commandID: String,
        verb: String,
        expectedUpdatedAt: String? = nil,
        payload: String
    ) throws {
        let staleField = expectedUpdatedAt.map { #", "expectedUpdatedAt": "\#($0)""# } ?? ""
        let json = """
        {
          "schemaVersion": 2,
          "commandID": "\(commandID)",
          "verb": "\(verb)"\(staleField),
          "payload": \(payload)
        }
        """
        try Data(json.utf8).write(to: inbox.appending(path: filename), options: .atomic)
    }

    func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    func pendingFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
    }

    func readManifest() throws -> AgentBridgeManifest {
        try JSONDecoder().decode(AgentBridgeManifest.self, from: Data(contentsOf: service.paths.manifestURL))
    }

    func outcome(commandID: String, failed: Bool = false) throws -> AgentBridgeOutcome {
        let directory = failed ? service.paths.failedURL : service.paths.processedURL
        let url = directory.appending(path: "\(commandID.lowercased()).outcome.json")
        return try JSONDecoder().decode(AgentBridgeOutcome.self, from: Data(contentsOf: url))
    }

    func failedOutcomes() throws -> [AgentBridgeOutcome] {
        try FileManager.default.contentsOfDirectory(at: service.paths.failedURL, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".outcome.json") }
            .map { try JSONDecoder().decode(AgentBridgeOutcome.self, from: Data(contentsOf: $0)) }
    }
}
