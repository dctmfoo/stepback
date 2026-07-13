import Foundation
import StepBackCore
import Testing

@Suite("Agent bridge plugin contract")
struct AgentBridgePluginContractTests {
    private var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "plugin", directoryHint: .isDirectory)
    }

    private var validationContext: AgentBridgeValidationContext {
        AgentBridgeValidationContext(
            categoryIDs: ["core", "legs-glutes"],
            workoutIDs: ["bridge"],
            routineIDs: [],
            commandResults: [
                "a2222222-2222-4222-8222-222222222222": "routine-result"
            ]
        )
    }

    @Test("Published schemas are valid JSON objects")
    func schemasParse() throws {
        for filename in ["command.schema.json", "manifest-v2.schema.json", "manifest.schema.json"] {
            let data = try Data(contentsOf: pluginRoot.appending(path: "schema/\(filename)"))
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(object["$schema"] as? String == "https://json-schema.org/draft/2020-12/schema")
            #expect(object["additionalProperties"] as? Bool == false)
        }
    }

    @Test("Manifest schemas preserve strict v2 and publish recency in v3")
    func manifestSchemaVersions() throws {
        let v2 = try schema(named: "manifest-v2.schema.json")
        let v3 = try schema(named: "manifest.schema.json")
        #expect((v2["properties"] as? [String: Any])?["schemaVersion"] as? [String: Int] == ["const": 2])
        #expect((v3["properties"] as? [String: Any])?["schemaVersion"] as? [String: Int] == ["const": 3])

        let v2Routine = try routineDefinition(in: v2)
        let v3Routine = try routineDefinition(in: v3)
        #expect(v2Routine["lastCompletedAt"] == nil)
        #expect(v3Routine["lastCompletedAt"] != nil)
    }

    @Test("Every valid fixture decodes and validates through production code")
    func validFixtures() throws {
        for filename in [
            "valid-create-custom-workout.json",
            "valid-create-routine.json",
            "valid-create-plan.json"
        ] {
            let data = try Data(contentsOf: pluginRoot.appending(path: "fixtures/\(filename)"))
            let command = try AgentBridgeCommandDecoder.decode(data)
            _ = try AgentBridgeCommandValidator.validate(command, context: validationContext)
        }
    }

    @Test("Every invalid fixture fails with its documented class")
    func invalidFixtures() throws {
        try expectDecoderFailure("invalid-delete-routine.json", .unknownVerb(field: "verb"))
        try expectValidationFailure(
            "invalid-deactivate-plan.json",
            .invalidField(field: "verb.deactivatePlan.use.activatePlan.to.setMyWeek")
        )
        try expectDecoderFailure("invalid-extra-field.json", .invalidField(field: "payload.deleteOthers"))
        try expectValidationFailure(
            "invalid-work-seconds.json",
            .invalidField(field: "payload.steps[0].workSeconds")
        )
        try expectValidationFailure(
            "invalid-unknown-workout.json",
            .unknownID(field: "payload.steps[0].workoutID")
        )
    }

    @Test("Claude and Codex wrappers both delegate to the shared instruction source")
    func skillsShareInstructions() throws {
        let claude = try String(
            contentsOf: pluginRoot.appending(path: "skills/stepback-coach/SKILL.md"),
            encoding: .utf8
        )
        let codex = try String(
            contentsOf: pluginRoot.appending(path: "codex-skills/stepback-coach/SKILL.md"),
            encoding: .utf8
        )
        let shared = try String(
            contentsOf: pluginRoot.appending(path: "shared/stepback-coach-instructions.md"),
            encoding: .utf8
        )

        #expect(claude.contains("../../shared/stepback-coach-instructions.md"))
        #expect(codex.contains("../../shared/stepback-coach-instructions.md"))
        #expect(shared.contains("wait for explicit conversational approval"))
        #expect(shared.contains("Deletion is never supported"))
        #expect(shared.contains("## Coach persona"))
        #expect(shared.contains("## Intake before composing"))
        #expect(shared.contains("## Programming defaults"))
        #expect(shared.contains("## Catalog-first composition"))
        #expect(shared.contains("## Safety envelope"))
        #expect(claude.contains("fitness coach"))
        #expect(claude.contains("routine or weekly schedule"))
        #expect(codex.contains("fitness coach"))
        #expect(codex.contains("routine or weekly schedule"))
    }

    private func expectDecoderFailure(
        _ filename: String,
        _ expected: AgentBridgeCommandError
    ) throws {
        let data = try Data(contentsOf: pluginRoot.appending(path: "fixtures/\(filename)"))
        #expect(throws: expected) {
            try AgentBridgeCommandDecoder.decode(data)
        }
    }

    private func expectValidationFailure(
        _ filename: String,
        _ expected: AgentBridgeCommandError
    ) throws {
        let data = try Data(contentsOf: pluginRoot.appending(path: "fixtures/\(filename)"))
        let command = try AgentBridgeCommandDecoder.decode(data)
        #expect(throws: expected) {
            try AgentBridgeCommandValidator.validate(command, context: validationContext)
        }
    }

    private func schema(named filename: String) throws -> [String: Any] {
        let data = try Data(contentsOf: pluginRoot.appending(path: "schema/\(filename)"))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func routineDefinition(in schema: [String: Any]) throws -> [String: Any] {
        let definitions = try #require(schema["$defs"] as? [String: Any])
        let routine = try #require(definitions["routine"] as? [String: Any])
        return try #require(routine["properties"] as? [String: Any])
    }
}
