import Foundation

public enum AgentBridgeCommandError: Error, Equatable, Sendable {
    case invalidJSON(field: String)
    case unsupportedSchema(field: String)
    case unknownVerb(field: String)
    case invalidField(field: String)
    case unknownID(field: String)

    public var field: String {
        switch self {
        case let .invalidJSON(field), let .unsupportedSchema(field), let .unknownVerb(field),
             let .invalidField(field), let .unknownID(field):
            field
        }
    }
}

public enum AgentBridgeVerb: String, Codable, CaseIterable, Sendable {
    case createCustomWorkout
    case updateCustomWorkout
    case createRoutine
    case updateRoutine
    case createPlan
    case updatePlan
    case activatePlan
    case deactivatePlan
}

public struct AgentCustomWorkoutPayload: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String
    public let categoryID: String
    public let notes: String?
}

public struct AgentRoutineStepPayload: Codable, Equatable, Sendable {
    public let workoutID: String
    public let workSeconds: Int
    public let sets: Int
    public let setRestSeconds: Int
    public let restAfterSeconds: Int
    public let repGuidance: Int?
}

public struct AgentRoutinePayload: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String
    public let steps: [AgentRoutineStepPayload]
}

public struct AgentRoutineReference: Codable, Equatable, Sendable {
    public let fromCommand: String
}

public struct AgentPlanSlotPayload: Codable, Equatable, Sendable {
    public let routineID: String?
    public let routineRef: AgentRoutineReference?
    public var resolvedRoutineID: String?

    enum CodingKeys: String, CodingKey {
        case routineID, routineRef
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        routineID = try values.decodeIfPresent(String.self, forKey: .routineID)
        routineRef = try values.decodeIfPresent(AgentRoutineReference.self, forKey: .routineRef)
        resolvedRoutineID = routineID
    }

    public init(
        routineID: String?,
        routineRef: AgentRoutineReference?,
        resolvedRoutineID: String?
    ) {
        self.routineID = routineID
        self.routineRef = routineRef
        self.resolvedRoutineID = resolvedRoutineID
    }
}

public struct AgentPlanDayPayload: Codable, Equatable, Sendable {
    public let weekday: Int
    public var slots: [AgentPlanSlotPayload]
}

public struct AgentPlanPayload: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String
    public var days: [AgentPlanDayPayload]
}

public struct AgentPlanActivationPayload: Codable, Equatable, Sendable {
    public let id: String
}

public enum AgentBridgePayload: Equatable, Sendable {
    case customWorkout(AgentCustomWorkoutPayload)
    case routine(AgentRoutinePayload)
    case plan(AgentPlanPayload)
    case planActivation(AgentPlanActivationPayload)
}

public struct AgentBridgeCommand: Equatable, Sendable {
    public let schemaVersion: Int
    public let commandID: String
    public let verb: AgentBridgeVerb
    public let expectedUpdatedAt: String?
    public let payload: AgentBridgePayload

    public var customWorkoutPayload: AgentCustomWorkoutPayload? {
        guard case let .customWorkout(value) = payload else { return nil }
        return value
    }

    public var routinePayload: AgentRoutinePayload? {
        guard case let .routine(value) = payload else { return nil }
        return value
    }

    public var planPayload: AgentPlanPayload? {
        guard case let .plan(value) = payload else { return nil }
        return value
    }

    public var planActivationPayload: AgentPlanActivationPayload? {
        guard case let .planActivation(value) = payload else { return nil }
        return value
    }
}

public enum AgentBridgeCommandDecoder {
    public static let schemaVersion = 2

    public static func decode(_ data: Data) throws -> AgentBridgeCommand {
        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AgentBridgeCommandError.invalidJSON(field: "root")
            }
            object = decoded
        } catch let error as AgentBridgeCommandError {
            throw error
        } catch {
            throw AgentBridgeCommandError.invalidJSON(field: "root")
        }

        try requireOnlyKeys(
            object,
            allowed: ["schemaVersion", "commandID", "verb", "expectedUpdatedAt", "payload"],
            prefix: ""
        )
        guard let version = object["schemaVersion"] as? Int else {
            throw AgentBridgeCommandError.invalidField(field: "schemaVersion")
        }
        guard version == schemaVersion else {
            throw AgentBridgeCommandError.unsupportedSchema(field: "schemaVersion")
        }
        guard let rawCommandID = object["commandID"] as? String,
              let commandUUID = UUID(uuidString: rawCommandID) else {
            throw AgentBridgeCommandError.invalidField(field: "commandID")
        }
        let commandID = commandUUID.uuidString.lowercased()
        let expectedUpdatedAt: String?
        if let rawTimestamp = object["expectedUpdatedAt"] {
            guard let timestamp = rawTimestamp as? String, iso8601Date(from: timestamp) != nil else {
                throw AgentBridgeCommandError.invalidField(field: "expectedUpdatedAt")
            }
            expectedUpdatedAt = timestamp
        } else {
            expectedUpdatedAt = nil
        }
        guard let verbValue = object["verb"] as? String else {
            throw AgentBridgeCommandError.invalidField(field: "verb")
        }
        guard let verb = AgentBridgeVerb(rawValue: verbValue) else {
            throw AgentBridgeCommandError.unknownVerb(field: "verb")
        }
        guard let payloadObject = object["payload"] as? [String: Any] else {
            throw AgentBridgeCommandError.invalidField(field: "payload")
        }

        try validatePayloadKeys(payloadObject, verb: verb)
        let payloadData: Data
        do {
            payloadData = try JSONSerialization.data(withJSONObject: payloadObject)
        } catch {
            throw AgentBridgeCommandError.invalidJSON(field: "payload")
        }
        let decoder = JSONDecoder()
        let payload: AgentBridgePayload
        do {
            switch verb {
            case .createCustomWorkout, .updateCustomWorkout:
                payload = .customWorkout(try decoder.decode(AgentCustomWorkoutPayload.self, from: payloadData))
            case .createRoutine, .updateRoutine:
                payload = .routine(try decoder.decode(AgentRoutinePayload.self, from: payloadData))
            case .createPlan, .updatePlan:
                payload = .plan(try decoder.decode(AgentPlanPayload.self, from: payloadData))
            case .activatePlan, .deactivatePlan:
                payload = .planActivation(try decoder.decode(AgentPlanActivationPayload.self, from: payloadData))
            }
        } catch {
            throw AgentBridgeCommandError.invalidField(field: decodingField(from: error))
        }

        return AgentBridgeCommand(
            schemaVersion: version,
            commandID: commandID,
            verb: verb,
            expectedUpdatedAt: expectedUpdatedAt,
            payload: payload
        )
    }

    private static func validatePayloadKeys(_ payload: [String: Any], verb: AgentBridgeVerb) throws {
        switch verb {
        case .createCustomWorkout, .updateCustomWorkout:
            try requireOnlyKeys(payload, allowed: ["id", "name", "categoryID", "notes"], prefix: "payload.")
        case .createRoutine, .updateRoutine:
            try requireOnlyKeys(payload, allowed: ["id", "name", "steps"], prefix: "payload.")
            if let steps = payload["steps"] as? [[String: Any]] {
                for (index, step) in steps.enumerated() {
                    try requireOnlyKeys(
                        step,
                        allowed: ["workoutID", "workSeconds", "sets", "setRestSeconds", "restAfterSeconds", "repGuidance"],
                        prefix: "payload.steps[\(index)]."
                    )
                }
            }
        case .createPlan, .updatePlan:
            try requireOnlyKeys(payload, allowed: ["id", "name", "days"], prefix: "payload.")
            if let days = payload["days"] as? [[String: Any]] {
                for (dayIndex, day) in days.enumerated() {
                    try requireOnlyKeys(day, allowed: ["weekday", "slots"], prefix: "payload.days[\(dayIndex)].")
                    if let slots = day["slots"] as? [[String: Any]] {
                        for (slotIndex, slot) in slots.enumerated() {
                            let prefix = "payload.days[\(dayIndex)].slots[\(slotIndex)]."
                            try requireOnlyKeys(slot, allowed: ["routineID", "routineRef"], prefix: prefix)
                            if let reference = slot["routineRef"] as? [String: Any] {
                                try requireOnlyKeys(reference, allowed: ["fromCommand"], prefix: prefix + "routineRef.")
                            }
                        }
                    }
                }
            }
        case .activatePlan, .deactivatePlan:
            try requireOnlyKeys(payload, allowed: ["id"], prefix: "payload.")
        }
    }

    private static func requireOnlyKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        prefix: String
    ) throws {
        if let key = Set(object.keys).subtracting(allowed).sorted().first {
            throw AgentBridgeCommandError.invalidField(field: prefix + key)
        }
    }

    private static func decodingField(from error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "payload" }
        let path: [any CodingKey]
        switch decodingError {
        case let .keyNotFound(key, context): path = context.codingPath + [key]
        case let .typeMismatch(_, context), let .valueNotFound(_, context), let .dataCorrupted(context):
            path = context.codingPath
        @unknown default: return "payload"
        }
        guard !path.isEmpty else { return "payload" }
        return "payload." + path.map(\.stringValue).joined(separator: ".")
    }

    private static func iso8601Date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

public struct AgentBridgeValidationContext: Sendable {
    public let categoryIDs: Set<String>
    public let workoutIDs: Set<String>
    public let routineIDs: Set<String>
    public let customWorkoutIDs: Set<String>
    public let planIDs: Set<String>
    public let commandResults: [String: String]

    public init(
        categoryIDs: Set<String>,
        workoutIDs: Set<String>,
        routineIDs: Set<String>,
        customWorkoutIDs: Set<String> = [],
        planIDs: Set<String> = [],
        commandResults: [String: String] = [:]
    ) {
        self.categoryIDs = categoryIDs
        self.workoutIDs = workoutIDs
        self.routineIDs = routineIDs
        self.customWorkoutIDs = customWorkoutIDs
        self.planIDs = planIDs
        self.commandResults = commandResults
    }
}

public enum AgentBridgeCommandValidator {
    public static let maxNameLength = 120
    public static let maxNotesLength = 2_000
    public static let maxSteps = 200
    public static let maxSlotsPerDay = 100

    public static func validate(
        _ command: AgentBridgeCommand,
        context: AgentBridgeValidationContext
    ) throws -> AgentBridgeCommand {
        switch command.payload {
        case let .customWorkout(payload):
            try validateName(payload.name)
            guard context.categoryIDs.contains(payload.categoryID) else {
                throw AgentBridgeCommandError.unknownID(field: "payload.categoryID")
            }
            if let notes = payload.notes, notes.count > maxNotesLength {
                throw AgentBridgeCommandError.invalidField(field: "payload.notes")
            }
            try validateTargetID(payload.id, verb: command.verb, allowed: context.customWorkoutIDs)
            return command

        case let .routine(payload):
            try validateName(payload.name)
            try validateTargetID(payload.id, verb: command.verb, allowed: context.routineIDs)
            if command.verb == .createRoutine, payload.steps.isEmpty {
                throw AgentBridgeCommandError.invalidField(field: "payload.steps")
            }
            guard payload.steps.count <= maxSteps else {
                throw AgentBridgeCommandError.invalidField(field: "payload.steps")
            }
            for (index, step) in payload.steps.enumerated() {
                let prefix = "payload.steps[\(index)]."
                guard context.workoutIDs.contains(step.workoutID) else {
                    throw AgentBridgeCommandError.unknownID(field: prefix + "workoutID")
                }
                try validate(step.workSeconds, in: 5...600, multipleOf: 5, field: prefix + "workSeconds")
                try validate(step.sets, in: 1...20, multipleOf: 1, field: prefix + "sets")
                try validate(step.setRestSeconds, in: 0...300, multipleOf: 5, field: prefix + "setRestSeconds")
                try validate(step.restAfterSeconds, in: 0...300, multipleOf: 5, field: prefix + "restAfterSeconds")
                if let guidance = step.repGuidance {
                    try validate(guidance, in: 5...100, multipleOf: 5, field: prefix + "repGuidance")
                }
            }
            return command

        case var .plan(payload):
            try validateName(payload.name)
            try validateTargetID(payload.id, verb: command.verb, allowed: context.planIDs)
            guard payload.days.count == 7,
                  Set(payload.days.map(\.weekday)) == Set(1...7) else {
                throw AgentBridgeCommandError.invalidField(field: "payload.days")
            }
            for dayIndex in payload.days.indices {
                guard payload.days[dayIndex].slots.count <= maxSlotsPerDay else {
                    throw AgentBridgeCommandError.invalidField(field: "payload.days[\(dayIndex)].slots")
                }
                for slotIndex in payload.days[dayIndex].slots.indices {
                    var slot = payload.days[dayIndex].slots[slotIndex]
                    let prefix = "payload.days[\(dayIndex)].slots[\(slotIndex)]."
                    guard (slot.routineID == nil) != (slot.routineRef == nil) else {
                        throw AgentBridgeCommandError.invalidField(field: prefix + "routineID")
                    }
                    if let routineID = slot.routineID {
                        guard context.routineIDs.contains(routineID) else {
                            throw AgentBridgeCommandError.unknownID(field: prefix + "routineID")
                        }
                        slot.resolvedRoutineID = routineID
                    } else if let reference = slot.routineRef {
                        guard let referenceUUID = UUID(uuidString: reference.fromCommand),
                              let resolved = context.commandResults[referenceUUID.uuidString.lowercased()] else {
                            throw AgentBridgeCommandError.unknownID(field: prefix + "routineRef.fromCommand")
                        }
                        slot.resolvedRoutineID = resolved
                    }
                    payload.days[dayIndex].slots[slotIndex] = slot
                }
            }
            return AgentBridgeCommand(
                schemaVersion: command.schemaVersion,
                commandID: command.commandID,
                verb: command.verb,
                expectedUpdatedAt: command.expectedUpdatedAt,
                payload: .plan(payload)
            )

        case let .planActivation(payload):
            if command.verb == .deactivatePlan {
                throw AgentBridgeCommandError.invalidField(
                    field: "verb.deactivatePlan.use.activatePlan.to.setMyWeek"
                )
            }
            guard context.planIDs.contains(payload.id) else {
                throw AgentBridgeCommandError.unknownID(field: "payload.id")
            }
            return command
        }
    }

    private static func validateName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxNameLength else {
            throw AgentBridgeCommandError.invalidField(field: "payload.name")
        }
    }

    private static func validateTargetID(
        _ id: String?,
        verb: AgentBridgeVerb,
        allowed: Set<String>
    ) throws {
        let isUpdate = verb == .updateCustomWorkout || verb == .updateRoutine || verb == .updatePlan
        if isUpdate {
            guard let id, allowed.contains(id) else {
                throw AgentBridgeCommandError.unknownID(field: "payload.id")
            }
        } else if id != nil {
            throw AgentBridgeCommandError.invalidField(field: "payload.id")
        }
    }

    private static func validate(
        _ value: Int,
        in range: ClosedRange<Int>,
        multipleOf: Int,
        field: String
    ) throws {
        guard range.contains(value), value.isMultiple(of: multipleOf) else {
            throw AgentBridgeCommandError.invalidField(field: field)
        }
    }
}
