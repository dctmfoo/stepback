import Foundation
import OSLog
import StepBackCore
import SwiftData

@MainActor
final class AgentBridgeService {
    let paths: AgentBridgePaths

    private let modelContext: ModelContext
    private let catalogService: WorkoutCatalogService
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private var monitorTask: Task<Void, Never>?
    private var lastManifestSnapshot: Data?

    init(
        modelContext: ModelContext,
        catalogService: WorkoutCatalogService,
        rootURL: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) throws {
        self.modelContext = modelContext
        self.catalogService = catalogService
        self.defaults = defaults
        self.fileManager = fileManager
        paths = try rootURL.map(AgentBridgePaths.init(rootURL:)) ?? .appDefault(fileManager: fileManager)
        defaults.register(defaults: [AgentBridgeSettings.allowChangesKey: true])
    }

    func prepare() throws {
        try ensureDirectories()
        try processPendingCommands()
        try refreshManifest(force: true)
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                    try self?.processPendingCommands()
                    try self?.refreshManifest()
                } catch is CancellationError {
                    return
                } catch {
                    Logger(subsystem: "com.nags.stepback", category: "AgentBridge")
                        .error("Monitoring failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func processPendingCommands() throws {
        try ensureDirectories()
        let files = try fileManager.contentsOfDirectory(
            at: paths.inboxURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        for file in files {
            do {
                try process(file)
            } catch {
                Logger(subsystem: "com.nags.stepback", category: "AgentBridge")
                    .error("Could not finish \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func refreshManifest(force: Bool = false) throws {
        let manifest = try makeManifest(generatedAt: "")
        let snapshot = try Self.encoder.encode(manifest)
        guard force || snapshot != lastManifestSnapshot else { return }
        var generated = manifest
        generated.generatedAt = AgentBridgeDateCoding.string(from: .now)
        try Self.encoder.encode(generated).write(to: paths.manifestURL, options: .atomic)
        lastManifestSnapshot = snapshot
    }

    private func process(_ file: URL) throws {
        guard file.pathExtension.lowercased() == "json" else {
            try failUnidentified(file, reason: .unsupportedFileType)
            return
        }
        let size: Int
        do {
            size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        } catch {
            try failUnidentified(file, reason: .invalidJSON)
            return
        }
        guard size <= AgentBridgeProtocol.maxCommandBytes else {
            try failUnidentified(file, reason: .fileTooLarge)
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            try failUnidentified(file, reason: .invalidJSON)
            return
        }
        guard data.count <= AgentBridgeProtocol.maxCommandBytes else {
            try failUnidentified(file, reason: .fileTooLarge, commandID: commandID(in: data))
            return
        }
        let command: AgentBridgeCommand
        do {
            command = try AgentBridgeCommandDecoder.decode(data)
        } catch let error as AgentBridgeCommandError {
            try failUnidentified(file, reason: reason(for: error), field: error.field, commandID: commandID(in: data))
            return
        } catch {
            try failUnidentified(file, reason: .invalidJSON, commandID: commandID(in: data))
            return
        }

        var log = try readProcessedLog()
        if var previous = log.outcomes[command.commandID] {
            previous.duplicateCommand = true
            previous.processedAt = AgentBridgeDateCoding.string(from: .now)
            try write(previous, to: outcomeURL(commandID: command.commandID, in: paths.processedURL))
            try archive(file, commandID: command.commandID, in: paths.processedURL)
            return
        }

        guard defaults.bool(forKey: AgentBridgeSettings.allowChangesKey) else {
            try fail(file, command: command, reason: .bridgeDisabled)
            return
        }

        let models = try fetchModels()
        let context = AgentBridgeValidationContext(
            categoryIDs: Set(catalogService.catalog.categories.map(\.id)),
            workoutIDs: Set(catalogService.catalog.workouts.map(\.id) + models.customWorkouts.map(\.id)),
            routineIDs: Set(models.routines.map(\.id)),
            customWorkoutIDs: Set(models.customWorkouts.map(\.id)),
            planIDs: Set(models.plans.map(\.id)),
            commandResults: log.outcomes.compactMapValues { $0.resultingIDs["routine"] }
        )

        let validated: AgentBridgeCommand
        do {
            validated = try AgentBridgeCommandValidator.validate(command, context: context)
            try validateStaleness(validated, models: models)
        } catch let error as AgentBridgeCommandError {
            try fail(file, command: command, reason: reason(for: error), field: error.field)
            return
        } catch AgentBridgeServiceError.staleObject {
            try fail(file, command: command, reason: .staleObject, field: "expectedUpdatedAt")
            return
        }

        let result: MutationResult
        do {
            result = try apply(validated, models: models)
        } catch let error as AgentBridgeServiceError {
            try fail(file, command: command, reason: error.reason, field: error.field)
            return
        } catch {
            try fail(file, command: command, reason: .ingestionFailed)
            return
        }

        let outcome = AgentBridgeOutcome(
            commandID: command.commandID,
            verb: command.verb.rawValue,
            status: .success,
            resultingIDs: result.ids,
            updatedAt: result.updatedAt.map(AgentBridgeDateCoding.string(from:))
        )
        log.outcomes[command.commandID] = outcome
        try writeProcessedLog(log)
        try write(outcome, to: outcomeURL(commandID: command.commandID, in: paths.processedURL))
        try archive(file, commandID: command.commandID, in: paths.processedURL)
        try refreshManifest(force: true)
    }

    private func apply(_ command: AgentBridgeCommand, models: FetchedModels) throws -> MutationResult {
        let now = Date.now
        switch command.verb {
        case .createCustomWorkout:
            let payload = try require(command.customWorkoutPayload)
            if let existing = models.customWorkouts.first(where: { $0.id == command.commandID }) {
                guard existing.lastEditedVia == "agent" else {
                    throw AgentBridgeServiceError.invalidField(field: "commandID")
                }
                return MutationResult(ids: ["customWorkout": existing.id], updatedAt: existing.updatedAt)
            }
            let workout = CustomWorkout(
                id: command.commandID,
                name: payload.name.trimmingCharacters(in: .whitespacesAndNewlines),
                categoryID: payload.categoryID,
                notes: trimmedOptional(payload.notes),
                createdAt: now,
                updatedAt: now,
                lastEditedVia: "agent"
            )
            modelContext.insert(workout)
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["customWorkout": workout.id], updatedAt: workout.updatedAt)

        case .updateCustomWorkout:
            let payload = try require(command.customWorkoutPayload)
            let workout = try require(models.customWorkouts.first { $0.id == payload.id }, field: "payload.id")
            workout.name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
            workout.categoryID = payload.categoryID
            workout.notes = trimmedOptional(payload.notes)
            workout.updatedAt = now
            workout.lastEditedVia = "agent"
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["customWorkout": workout.id], updatedAt: workout.updatedAt)

        case .createRoutine:
            let payload = try require(command.routinePayload)
            if let existing = models.routines.first(where: { $0.id == command.commandID }) {
                guard existing.lastEditedVia == "agent" else {
                    throw AgentBridgeServiceError.invalidField(field: "commandID")
                }
                return MutationResult(ids: ["routine": existing.id], updatedAt: existing.updatedAt)
            }
            let routine = Routine(
                id: command.commandID,
                name: payload.name.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: now,
                updatedAt: now,
                lastEditedVia: "agent"
            )
            routine.steps = try makeSteps(payload.steps, routine: routine, models: models)
            modelContext.insert(routine)
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["routine": routine.id], updatedAt: routine.updatedAt)

        case .updateRoutine:
            let payload = try require(command.routinePayload)
            let routine = try require(models.routines.first { $0.id == payload.id }, field: "payload.id")
            for step in routine.steps ?? [] { modelContext.delete(step) }
            routine.name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
            routine.steps = try makeSteps(payload.steps, routine: routine, models: models)
            routine.updatedAt = now
            routine.lastEditedVia = "agent"
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["routine": routine.id], updatedAt: routine.updatedAt)

        case .createPlan:
            let payload = try require(command.planPayload)
            if let existing = models.plans.first(where: { $0.id == command.commandID }) {
                guard existing.lastEditedVia == "agent" else {
                    throw AgentBridgeServiceError.invalidField(field: "commandID")
                }
                return MutationResult(ids: ["plan": existing.id], updatedAt: existing.updatedAt)
            }
            let plan = Plan(
                id: command.commandID,
                name: payload.name.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: now,
                updatedAt: now,
                isActive: models.plans.isEmpty,
                weeklyScheduleVersion: 1,
                lastEditedVia: "agent"
            )
            plan.slots = try makeSlots(payload.days, plan: plan, models: models)
            modelContext.insert(plan)
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["plan": plan.id], updatedAt: plan.updatedAt)

        case .updatePlan:
            let payload = try require(command.planPayload)
            let plan = try require(models.plans.first { $0.id == payload.id }, field: "payload.id")
            let editor = PlanEditorModel.editing(plan)
            editor.name = payload.name
            editor.days = try draftDays(payload.days, preservingSlotsFrom: plan, models: models)
            _ = try editor.save(existing: plan, in: modelContext, now: now)
            plan.lastEditedVia = "agent"
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["plan": plan.id], updatedAt: plan.updatedAt)

        case .activatePlan:
            let payload = try require(command.planActivationPayload)
            let plan = try require(models.plans.first { $0.id == payload.id }, field: "payload.id")
            try PlanLibrary.setMyWeek(plan, among: models.plans, in: modelContext)
            plan.lastEditedVia = "agent"
            try modelContext.saveOrRollback()
            return MutationResult(ids: ["plan": plan.id], updatedAt: plan.updatedAt)

        case .deactivatePlan:
            throw AgentBridgeServiceError.invalidField(
                field: "verb.deactivatePlan.use.activatePlan.to.setMyWeek"
            )
        }
    }

    private func makeSteps(
        _ payloads: [AgentRoutineStepPayload],
        routine: Routine,
        models: FetchedModels
    ) throws -> [RoutineStep] {
        try payloads.enumerated().map { index, payload in
            RoutineStep(
                sortIndex: index,
                workoutID: payload.workoutID,
                workoutNameSnapshot: try workoutName(payload.workoutID, models: models),
                workSeconds: payload.workSeconds,
                sets: payload.sets,
                setRestSeconds: payload.setRestSeconds,
                restAfterSeconds: payload.restAfterSeconds,
                repGuidance: payload.repGuidance,
                routine: routine
            )
        }
    }

    private func makeSlots(
        _ days: [AgentPlanDayPayload],
        plan: Plan,
        models: FetchedModels
    ) throws -> [PlanSlot] {
        try days.enumerated().flatMap { dayIndex, day in
            try day.slots.enumerated().map { slotIndex, payload in
                let routine = try require(
                    models.routines.first { $0.id == payload.resolvedRoutineID },
                    field: "payload.days[\(dayIndex)].slots[\(slotIndex)].routineID"
                )
                return PlanSlot(
                    weekIndex: 0,
                    sortIndex: slotIndex,
                    weekdayLabelIndex: day.weekday,
                    plan: plan,
                    routine: routine
                )
            }
        }
    }

    private func draftDays(
        _ days: [AgentPlanDayPayload],
        preservingSlotsFrom plan: Plan,
        models: FetchedModels
    ) throws -> [PlanDraftDay] {
        var available = (plan.slots ?? []).sorted(by: PlanSlot.sortOrder)
        return try days.enumerated().map { dayIndex, day in
            let slots = try day.slots.enumerated().map { slotIndex, payload in
                let routine = try require(
                    models.routines.first { $0.id == payload.resolvedRoutineID },
                    field: "payload.days[\(dayIndex)].slots[\(slotIndex)].routineID"
                )
                let matchIndex = available.firstIndex { $0.routineID == routine.id }
                let source = matchIndex.map { available.remove(at: $0) }
                return PlanDraftSlot(
                    sourceSlot: source,
                    routine: routine
                )
            }
            return PlanDraftDay(weekday: day.weekday, slots: slots)
        }
    }

    private func workoutName(_ id: String, models: FetchedModels) throws -> String {
        if let custom = models.customWorkouts.first(where: { $0.id == id }) { return custom.name }
        if let definition = catalogService.catalog.workouts.first(where: { $0.id == id }) {
            return catalogService.localizedString(for: definition.nameKey)
        }
        throw AgentBridgeServiceError.unknownID(field: "payload.workoutID")
    }

    private func validateStaleness(_ command: AgentBridgeCommand, models: FetchedModels) throws {
        guard let expected = command.expectedUpdatedAt else { return }
        let actual: Date?
        switch command.payload {
        case let .customWorkout(payload): actual = models.customWorkouts.first { $0.id == payload.id }?.updatedAt
        case let .routine(payload): actual = models.routines.first { $0.id == payload.id }?.updatedAt
        case let .plan(payload): actual = models.plans.first { $0.id == payload.id }?.updatedAt
        case let .planActivation(payload): actual = models.plans.first { $0.id == payload.id }?.updatedAt
        }
        guard let actual, AgentBridgeDateCoding.string(from: actual) == expected else {
            throw AgentBridgeServiceError.staleObject
        }
    }

    private func makeManifest(generatedAt: String) throws -> AgentBridgeManifest {
        let models = try fetchModels()
        let categories = catalogService.catalog.categories.map {
            AgentBridgeManifest.Category(
                id: $0.id,
                displayName: catalogService.localizedString(for: $0.nameKey),
                symbolName: $0.symbolName
            )
        }
        let catalogWorkouts = catalogService.catalog.workouts.map {
            AgentBridgeManifest.CatalogWorkout(
                id: $0.id,
                displayName: catalogService.localizedString(for: $0.nameKey),
                categoryID: $0.categoryID,
                focusAreas: $0.focusAreas
            )
        }
        let custom = models.customWorkouts.sorted(by: { $0.id < $1.id }).map {
            AgentBridgeManifest.CustomWorkoutEntry(
                id: $0.id,
                name: $0.name,
                categoryID: $0.categoryID,
                notes: $0.notes,
                createdAt: AgentBridgeDateCoding.string(from: $0.createdAt),
                updatedAt: AgentBridgeDateCoding.string(from: $0.updatedAt),
                lastEditedVia: $0.lastEditedVia
            )
        }
        let routines = models.routines.sorted(by: { $0.id < $1.id }).map { routine in
            let sessions = routine.sessions ?? []
            let completion = sessions.reduce(into: (count: 0, latestEnd: Optional<Date>.none)) { result, session in
                guard session.wasCompleted else { return }
                result.count += 1
                guard let endedAt = session.endedAt, endedAt > (result.latestEnd ?? .distantPast) else { return }
                result.latestEnd = endedAt
            }
            return AgentBridgeManifest.RoutineEntry(
                id: routine.id,
                name: routine.name,
                createdAt: AgentBridgeDateCoding.string(from: routine.createdAt),
                updatedAt: AgentBridgeDateCoding.string(from: routine.updatedAt),
                lastEditedVia: routine.lastEditedVia,
                totalSeconds: TimelineCompiler.totalDurationSeconds(routine.snapshot, getReadySeconds: 0),
                sessionCount: sessions.count,
                completedSessionCount: completion.count,
                lastCompletedAt: completion.latestEnd.map(AgentBridgeDateCoding.string(from:)),
                steps: (routine.steps ?? []).sorted { $0.sortIndex < $1.sortIndex }.map {
                    AgentBridgeManifest.RoutineStepEntry(
                        workoutID: $0.workoutID,
                        workoutName: $0.workoutNameSnapshot,
                        workSeconds: $0.workSeconds,
                        sets: $0.sets,
                        setRestSeconds: $0.setRestSeconds,
                        restAfterSeconds: $0.restAfterSeconds,
                        repGuidance: $0.repGuidance
                    )
                }
            )
        }
        let plans = models.plans.sorted(by: { $0.id < $1.id }).map { plan in
            let slots = (plan.slots ?? []).sorted(by: PlanSlot.sortOrder)
            return AgentBridgeManifest.PlanEntry(
                id: plan.id,
                name: plan.name,
                createdAt: AgentBridgeDateCoding.string(from: plan.createdAt),
                updatedAt: AgentBridgeDateCoding.string(from: plan.updatedAt),
                lastEditedVia: plan.lastEditedVia,
                isMyWeek: plan.isActive,
                days: (1...7).map { weekday in
                    AgentBridgeManifest.PlanDayEntry(
                        weekday: weekday,
                        slots: slots.filter { $0.weekdayLabelIndex == weekday }.map {
                            AgentBridgeManifest.PlanSlotEntry(
                                id: $0.id,
                                index: $0.sortIndex,
                                routineID: $0.routineID,
                                routineName: $0.routineNameSnapshot,
                                routineExists: $0.routine != nil
                            )
                        }
                    )
                }
            )
        }
        return AgentBridgeManifest(
            schemaVersion: AgentBridgeProtocol.manifestSchemaVersion,
            generatedAt: generatedAt,
            rootPath: paths.rootURL.path,
            inboxPath: paths.inboxURL.path,
            processedPath: paths.processedURL.path,
            failedPath: paths.failedURL.path,
            catalogVersion: catalogService.catalog.catalogVersion,
            categories: categories,
            catalogWorkouts: catalogWorkouts,
            customWorkouts: custom,
            routines: routines,
            plans: plans
        )
    }

    private func fetchModels() throws -> FetchedModels {
        FetchedModels(
            customWorkouts: try modelContext.fetch(FetchDescriptor<CustomWorkout>()),
            routines: try modelContext.fetch(FetchDescriptor<Routine>()),
            plans: try modelContext.fetch(FetchDescriptor<Plan>())
        )
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: paths.inboxURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.processedURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.failedURL, withIntermediateDirectories: true)
    }

    private func fail(
        _ file: URL,
        command: AgentBridgeCommand,
        reason: AgentBridgeFailureReason,
        field: String? = nil
    ) throws {
        let outcome = AgentBridgeOutcome(
            commandID: command.commandID,
            verb: command.verb.rawValue,
            status: .failure,
            reason: reason,
            field: field
        )
        try write(outcome, to: outcomeURL(commandID: command.commandID, in: paths.failedURL))
        try archive(file, commandID: command.commandID, in: paths.failedURL)
    }

    private func failUnidentified(
        _ file: URL,
        reason: AgentBridgeFailureReason,
        field: String? = nil,
        commandID: String? = nil
    ) throws {
        let id = commandID ?? UUID().uuidString
        let outcome = AgentBridgeOutcome(
            commandID: id,
            status: .failure,
            reason: reason,
            field: field
        )
        try write(outcome, to: outcomeURL(commandID: id, in: paths.failedURL))
        try archive(file, commandID: id, in: paths.failedURL)
    }

    private func archive(_ source: URL, commandID: String, in directory: URL) throws {
        let filename = "\(commandID.lowercased()).command-\(UUID().uuidString.lowercased()).json"
        try fileManager.moveItem(at: source, to: directory.appending(path: filename))
    }

    private func outcomeURL(commandID: String, in directory: URL) -> URL {
        directory.appending(path: "\(commandID.lowercased()).outcome.json")
    }

    private func readProcessedLog() throws -> AgentBridgeProcessedLog {
        guard fileManager.fileExists(atPath: paths.processedLogURL.path) else {
            return AgentBridgeProcessedLog()
        }
        let data = try Data(contentsOf: paths.processedLogURL)
        return try JSONDecoder().decode(AgentBridgeProcessedLog.self, from: data)
    }

    private func writeProcessedLog(_ log: AgentBridgeProcessedLog) throws {
        try write(log, to: paths.processedLogURL)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try Self.encoder.encode(value).write(to: url, options: .atomic)
    }

    private func commandID(in data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["commandID"] as? String,
              let uuid = UUID(uuidString: value) else {
            return nil
        }
        return uuid.uuidString.lowercased()
    }

    private func reason(for error: AgentBridgeCommandError) -> AgentBridgeFailureReason {
        switch error {
        case .invalidJSON: .invalidJSON
        case .unsupportedSchema: .unsupportedSchema
        case .unknownVerb: .unknownVerb
        case .invalidField: .invalidField
        case .unknownID: .unknownID
        }
    }

    private func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func require<T>(_ value: T?, field: String = "payload") throws -> T {
        guard let value else { throw AgentBridgeServiceError.unknownID(field: field) }
        return value
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
}

private struct FetchedModels {
    var customWorkouts: [CustomWorkout]
    var routines: [Routine]
    var plans: [Plan]
}

private struct MutationResult {
    var ids: [String: String]
    var updatedAt: Date?
}

private enum AgentBridgeServiceError: Error {
    case staleObject
    case unknownID(field: String)
    case invalidField(field: String)

    var reason: AgentBridgeFailureReason {
        switch self {
        case .staleObject: .staleObject
        case .unknownID: .unknownID
        case .invalidField: .invalidField
        }
    }

    var field: String? {
        switch self {
        case .staleObject: "expectedUpdatedAt"
        case let .unknownID(field): field
        case let .invalidField(field): field
        }
    }
}
