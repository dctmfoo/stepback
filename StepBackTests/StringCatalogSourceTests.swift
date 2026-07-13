import Foundation
import Testing

@Suite("String catalog source discipline")
struct StringCatalogSourceTests {
    @Test("Feature UI does not construct user-facing literals outside L10n")
    func userFacingStringsResolveThroughCatalogOrFormatters() throws {
        let featureRoot = repositoryRoot
            .appending(path: "StepBack/Features", directoryHint: .isDirectory)
        let files = try FileManager.default.contentsOfDirectory(
            at: featureRoot,
            includingPropertiesForKeys: nil
        )

        var violations: [String] = []
        for directory in files where directory.hasDirectoryPath {
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
            while let file = enumerator?.nextObject() as? URL {
                guard file.pathExtension == "swift", file.lastPathComponent != "L10n.swift" else { continue }
                let source = try String(contentsOf: file, encoding: .utf8)
                violations += sourceViolations(in: source, file: file)
            }
        }

        #expect(
            violations.isEmpty,
            "User-facing strings must resolve through L10n or Foundation formatters:\n\(violations.joined(separator: "\n"))"
        )
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceViolations(in source: String, file: URL) -> [String] {
        let directDisplayLiteral = try! Regex(
            #"\b(?:Text|TextField|SecureField|Button|Link|Label|Toggle|Picker|Menu|Section|ContentUnavailableView|navigationTitle|navigationSubtitle|confirmationDialog|alert|accessibilityLabel|accessibilityValue|accessibilityHint)\s*\(\s*\""#
        )
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, line in
                let text = String(line)
                let rawNumericInterpolation = text.contains("value: \"\\(")
                    && ["seconds", "count", "sets"].contains(where: text.contains)
                guard text.contains(directDisplayLiteral) || rawNumericInterpolation else {
                    return nil
                }
                return "\(file.lastPathComponent):\(offset + 1): \(text.trimmingCharacters(in: .whitespaces))"
            }
    }
}
