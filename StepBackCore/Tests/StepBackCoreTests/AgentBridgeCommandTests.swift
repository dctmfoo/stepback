import Foundation
import Testing
@testable import StepBackCore

@Suite("Agent bridge command contract")
struct AgentBridgeCommandTests {
    private let context = AgentBridgeValidationContext(
        categoryIDs: ["core", "legs-glutes"],
        workoutIDs: ["bridge", "squat", "custom-1"],
        routineIDs: ["routine-1"],
        customWorkoutIDs: ["custom-1"],
        planIDs: ["plan-1"],
        commandResults: ["a1111111-1111-4111-8111-111111111111": "routine-created"]
    )

    @Test("All supported verbs decode and validate")
    func supportedVerbs() throws {
        let commands = [
            command(verb: "createCustomWorkout", payload: #"{"name":"Wall Sit","categoryID":"legs-glutes","notes":"Back flat"}"#),
            command(verb: "updateCustomWorkout", payload: #"{"id":"custom-1","name":"Wall Sit","categoryID":"legs-glutes"}"#),
            command(verb: "createRoutine", payload: #"{"name":"Core","steps":[{"workoutID":"bridge","workSeconds":30,"sets":3,"setRestSeconds":10,"restAfterSeconds":15}]}"#),
            command(verb: "updateRoutine", payload: #"{"id":"routine-1","name":"Core","steps":[]}"#),
            command(verb: "createPlan", payload: planPayload()),
            command(verb: "updatePlan", payload: planPayload(id: "plan-1")),
            command(verb: "activatePlan", payload: #"{"id":"plan-1"}"#)
        ]

        let decoded = try commands.map { try AgentBridgeCommandDecoder.decode(Data($0.utf8)) }
        for command in decoded {
            _ = try AgentBridgeCommandValidator.validate(command, context: context)
        }

        #expect(decoded.map(\.verb.rawValue) == [
            "createCustomWorkout", "updateCustomWorkout", "createRoutine", "updateRoutine",
            "createPlan", "updatePlan", "activatePlan"
        ])
    }

    @Test("Deactivate Plan is rejected with the My Week replacement")
    func deactivatePlanIsRetired() throws {
        let command = try AgentBridgeCommandDecoder.decode(Data(self.command(
            verb: "deactivatePlan",
            payload: #"{"id":"plan-1"}"#
        ).utf8))
        #expect(throws: AgentBridgeCommandError.invalidField(
            field: "verb.deactivatePlan.use.activatePlan.to.setMyWeek"
        )) {
            try AgentBridgeCommandValidator.validate(command, context: context)
        }
    }

    @Test("Delete-shaped and unknown verbs fail as unknown-verb")
    func rejectsDeleteVerbs() {
        for verb in ["deleteRoutine", "archivePlan", "runShell"] {
            #expect(throws: AgentBridgeCommandError.unknownVerb(field: "verb")) {
                try AgentBridgeCommandDecoder.decode(Data(command(verb: verb, payload: "{}").utf8))
            }
        }
    }

    @Test("Envelope and payload decoding is strict")
    func strictDecoding() {
        let extraEnvelope = command(
            verb: "activatePlan",
            payload: #"{"id":"plan-1"}"#,
            extra: #", "deleteAfter": true"#
        )
        #expect(throws: AgentBridgeCommandError.invalidField(field: "deleteAfter")) {
            try AgentBridgeCommandDecoder.decode(Data(extraEnvelope.utf8))
        }

        let extraPayload = command(
            verb: "createCustomWorkout",
            payload: #"{"name":"Wall Sit","categoryID":"legs-glutes","deleteOthers":true}"#
        )
        #expect(throws: AgentBridgeCommandError.invalidField(field: "payload.deleteOthers")) {
            try AgentBridgeCommandDecoder.decode(Data(extraPayload.utf8))
        }
    }

    @Test("Validation names exact fields and rejects invalid references and bounds")
    func validatesFields() throws {
        let unknownWorkout = try AgentBridgeCommandDecoder.decode(Data(command(
            verb: "createRoutine",
            payload: #"{"name":"Core","steps":[{"workoutID":"imaginary","workSeconds":30,"sets":1,"setRestSeconds":0,"restAfterSeconds":0}]}"#
        ).utf8))
        #expect(throws: AgentBridgeCommandError.unknownID(field: "payload.steps[0].workoutID")) {
            try AgentBridgeCommandValidator.validate(unknownWorkout, context: context)
        }

        let invalidSeconds = try AgentBridgeCommandDecoder.decode(Data(command(
            verb: "createRoutine",
            payload: #"{"name":"Core","steps":[{"workoutID":"bridge","workSeconds":601,"sets":1,"setRestSeconds":0,"restAfterSeconds":0}]}"#
        ).utf8))
        #expect(throws: AgentBridgeCommandError.invalidField(field: "payload.steps[0].workSeconds")) {
            try AgentBridgeCommandValidator.validate(invalidSeconds, context: context)
        }

        let whitespaceName = try AgentBridgeCommandDecoder.decode(Data(command(
            verb: "createCustomWorkout",
            payload: #"{"name":"   ","categoryID":"core"}"#
        ).utf8))
        #expect(throws: AgentBridgeCommandError.invalidField(field: "payload.name")) {
            try AgentBridgeCommandValidator.validate(whitespaceName, context: context)
        }

        let duplicateWeekday = try AgentBridgeCommandDecoder.decode(Data(command(
            verb: "createPlan",
            payload: #"{"name":"Duplicate","days":[{"weekday":1,"slots":[]},{"weekday":1,"slots":[]},{"weekday":2,"slots":[]},{"weekday":3,"slots":[]},{"weekday":4,"slots":[]},{"weekday":5,"slots":[]},{"weekday":6,"slots":[]}]}"#
        ).utf8))
        #expect(throws: AgentBridgeCommandError.invalidField(field: "payload.days")) {
            try AgentBridgeCommandValidator.validate(duplicateWeekday, context: context)
        }
    }

    @Test("Plan placeholders resolve only from prior successful command results")
    func placeholderResolution() throws {
        let command = try AgentBridgeCommandDecoder.decode(Data(self.command(
            verb: "createPlan",
            payload: planPayload(routineReference: "A1111111-1111-4111-8111-111111111111")
        ).utf8))

        let validated = try AgentBridgeCommandValidator.validate(command, context: context)
        let payload = try #require(validated.planPayload)
        #expect(payload.days[0].slots[0].resolvedRoutineID == "routine-created")

        let unresolved = try AgentBridgeCommandDecoder.decode(Data(self.command(
            verb: "createPlan",
            payload: planPayload(routineReference: "missing")
        ).utf8))
        #expect(throws: AgentBridgeCommandError.unknownID(field: "payload.days[0].slots[0].routineRef.fromCommand")) {
            try AgentBridgeCommandValidator.validate(unresolved, context: context)
        }
    }

    @Test("Command IDs must be UUIDs and schema version must be supported")
    func envelopeIdentityAndVersion() {
        let badID = command(verb: "activatePlan", payload: #"{"id":"plan-1"}"#, commandID: "not-a-uuid")
        #expect(throws: AgentBridgeCommandError.invalidField(field: "commandID")) {
            try AgentBridgeCommandDecoder.decode(Data(badID.utf8))
        }

        let future = command(verb: "activatePlan", payload: #"{"id":"plan-1"}"#, schemaVersion: 3)
        #expect(throws: AgentBridgeCommandError.unsupportedSchema(field: "schemaVersion")) {
            try AgentBridgeCommandDecoder.decode(Data(future.utf8))
        }

        let invalidTimestamp = """
        {
          "schemaVersion": 2,
          "commandID": "C93476F2-78F2-4B68-8C52-D122083F7488",
          "verb": "activatePlan",
          "expectedUpdatedAt": 42,
          "payload": {"id":"plan-1"}
        }
        """
        #expect(throws: AgentBridgeCommandError.invalidField(field: "expectedUpdatedAt")) {
            try AgentBridgeCommandDecoder.decode(Data(invalidTimestamp.utf8))
        }

        let normalized = try? AgentBridgeCommandDecoder.decode(Data(command(
            verb: "activatePlan",
            payload: #"{"id":"plan-1"}"#,
            commandID: "C93476F2-78F2-4B68-8C52-D122083F7488"
        ).utf8))
        #expect(normalized?.commandID == "c93476f2-78f2-4b68-8c52-d122083f7488")
    }

    private func command(
        verb: String,
        payload: String,
        commandID: String = "C93476F2-78F2-4B68-8C52-D122083F7488",
        schemaVersion: Int = 2,
        extra: String = ""
    ) -> String {
        """
        {
          "schemaVersion": \(schemaVersion),
          "commandID": "\(commandID)",
          "verb": "\(verb)",
          "payload": \(payload)\(extra)
        }
        """
    }

    private func planPayload(id: String? = nil, routineReference: String? = nil) -> String {
        let identifier = id.map { "\"id\":\"\($0)\"," } ?? ""
        let slot: String
        if let routineReference {
            slot = #"{"routineRef":{"fromCommand":"\#(routineReference)"}}"#
        } else {
            slot = #"{"routineID":"routine-1"}"#
        }
        return """
        {\(identifier)"name":"Split","days":[
          {"weekday":1,"slots":[\(slot)]},
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
