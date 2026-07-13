#if os(macOS)
import AppKit

enum AgentBridgeFolderRevealer {
    static func reveal() {
        guard let paths = try? AgentBridgePaths.appDefault() else { return }
        try? FileManager.default.createDirectory(at: paths.rootURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([paths.rootURL])
    }
}
#endif
