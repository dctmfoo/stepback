import Foundation
import Testing

@Suite("Color token contrast")
struct ColorTokenContrastTests {
    @Test("Secondary and stage text tokens retain enhanced contrast")
    func textTokensMeetEnhancedContrast() throws {
        let secondaryLight = try assetColor(named: "SecondaryText", dark: false)
        let secondaryDark = try assetColor(named: "SecondaryText", dark: true)
        let stageTextDim = try assetColor(named: "StageTextDim", dark: false)
        let stageCanvas = try assetColor(named: "StageCanvas", dark: false)

        #expect(contrastRatio(secondaryLight, over: .white) >= 7)
        #expect(contrastRatio(secondaryDark, over: .black) >= 7)
        #expect(contrastRatio(stageTextDim, over: stageCanvas) >= 7)
    }

    private struct RGBA {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        static let white = RGBA(red: 1, green: 1, blue: 1, alpha: 1)
        static let black = RGBA(red: 0, green: 0, blue: 0, alpha: 1)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assetColor(named name: String, dark: Bool) throws -> RGBA {
        let url = repositoryRoot
            .appending(path: "StepBack/Resources/Assets.xcassets", directoryHint: .isDirectory)
            .appending(path: "\(name).colorset/Contents.json")
        let data = try Data(contentsOf: url)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try #require(json["colors"] as? [[String: Any]])
        let entry = try #require(colors.first { color in
            let appearances = color["appearances"] as? [[String: String]]
            let isDark = appearances?.contains {
                $0["appearance"] == "luminosity" && $0["value"] == "dark"
            } == true
            return isDark == dark
        })
        let color = try #require(entry["color"] as? [String: Any])
        let components = try #require(color["components"] as? [String: String])
        return RGBA(
            red: try component(components["red"]),
            green: try component(components["green"]),
            blue: try component(components["blue"]),
            alpha: try component(components["alpha"])
        )
    }

    private func component(_ value: String?) throws -> Double {
        let value = try #require(value)
        if value.hasPrefix("0x") {
            let byte = try #require(Int(value.dropFirst(2), radix: 16))
            return Double(byte) / 255
        }
        return try #require(Double(value))
    }

    private func contrastRatio(_ foreground: RGBA, over background: RGBA) -> Double {
        let composited = RGBA(
            red: foreground.red * foreground.alpha + background.red * (1 - foreground.alpha),
            green: foreground.green * foreground.alpha + background.green * (1 - foreground.alpha),
            blue: foreground.blue * foreground.alpha + background.blue * (1 - foreground.alpha),
            alpha: 1
        )
        let lighter = max(relativeLuminance(composited), relativeLuminance(background))
        let darker = min(relativeLuminance(composited), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: RGBA) -> Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red)
            + 0.7152 * linear(color.green)
            + 0.0722 * linear(color.blue)
    }
}
