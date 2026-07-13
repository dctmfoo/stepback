import Foundation

enum AgentBridgeProtocol {
    static let commandSchemaVersion = 2
    static let manifestSchemaVersion = 3
    static let maxCommandBytes = 1_048_576
    static let rootDirectoryName = "AgentBridge"
    static let manifestFilename = "manifest.json"
    static let inboxDirectoryName = "inbox"
    static let processedDirectoryName = "processed"
    static let failedDirectoryName = "failed"
    static let processedLogFilename = "processed-log.json"
}

enum AgentBridgeSettings {
    static let allowChangesKey = "agentBridge.allowChanges"
}

enum AgentBridgeDateCoding {
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

}

enum AgentBridgeOutcomeStatus: String, Codable, Equatable {
    case success
    case failure
}

enum AgentBridgeFailureReason: String, Codable, Equatable {
    case unsupportedSchema = "unsupported-schema"
    case invalidJSON = "invalid-json"
    case unknownVerb = "unknown-verb"
    case invalidField = "invalid-field"
    case unknownID = "unknown-id"
    case staleObject = "stale-object"
    case bridgeDisabled = "bridge-disabled"
    case fileTooLarge = "file-too-large"
    case unsupportedFileType = "unsupported-file-type"
    case ingestionFailed = "ingestion-failed"
}

struct AgentBridgeOutcome: Codable, Equatable {
    var schemaVersion = AgentBridgeProtocol.commandSchemaVersion
    var commandID: String
    var verb: String?
    var status: AgentBridgeOutcomeStatus
    var reason: AgentBridgeFailureReason?
    var field: String?
    var resultingIDs: [String: String] = [:]
    var updatedAt: String?
    var duplicateCommand = false
    var processedAt = AgentBridgeDateCoding.string(from: .now)
}

struct AgentBridgeProcessedLog: Codable {
    var outcomes: [String: AgentBridgeOutcome] = [:]
}

struct AgentBridgePaths {
    let rootURL: URL

    var manifestURL: URL { rootURL.appending(path: AgentBridgeProtocol.manifestFilename) }
    var inboxURL: URL { rootURL.appending(path: AgentBridgeProtocol.inboxDirectoryName, directoryHint: .isDirectory) }
    var processedURL: URL { rootURL.appending(path: AgentBridgeProtocol.processedDirectoryName, directoryHint: .isDirectory) }
    var failedURL: URL { rootURL.appending(path: AgentBridgeProtocol.failedDirectoryName, directoryHint: .isDirectory) }
    var processedLogURL: URL { rootURL.appending(path: AgentBridgeProtocol.processedLogFilename) }

    static func appDefault(fileManager: FileManager = .default) throws -> AgentBridgePaths {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return AgentBridgePaths(
            rootURL: support.appending(path: AgentBridgeProtocol.rootDirectoryName, directoryHint: .isDirectory)
        )
    }
}
