import XCTest

@MainActor
final class StepBackPerformanceTests: XCTestCase {
    private static let optInEnvironmentKey = "StepBackAcceptancePerformance"

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard isOptedIn else {
            throw XCTSkip("Set \(Self.optInEnvironmentKey)=1 to run acceptance measurements.")
        }
    }

    func testColdLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = acceptanceApp()
            app.launch()
            XCTAssertTrue(tab("tab.routines", in: app).waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    func testPlayTapToPreRollPerformance() throws {
        let metric = XCTOSSignpostMetric(
            subsystem: "com.nags.stepback",
            category: "player",
            name: "PlayToPreRoll"
        )

        measure(metrics: [metric]) {
            let app = acceptanceApp()
            app.launch()
            let play = app.buttons["Play Quick Start"]
            XCTAssertTrue(play.waitForExistence(timeout: 3))
            play.tap()
            XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 3))
            app.terminate()
        }
    }

    func testFullCatalogGalleryScrollSmoke() throws {
        let app = acceptanceApp()
        app.launch()
        XCTAssertTrue(tab("tab.gallery", in: app).waitForExistence(timeout: 3))
        tab("tab.gallery", in: app).tap()
        XCTAssertTrue(app.descendants(matching: .any)["gallery.search"].waitForExistence(timeout: 3))

        for _ in 0..<6 { app.swipeUp() }
        for _ in 0..<6 { app.swipeDown() }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Full catalog gallery after acceptance scroll smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func acceptanceApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-StepBackUITesting")
        return app
    }

    private func tab(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let matches = app.buttons.matching(identifier: identifier)
        let nestedItem = matches.element(boundBy: 1)
        return nestedItem.exists ? nestedItem : matches.firstMatch
    }

    private var isOptedIn: Bool {
        #if STEPBACK_ACCEPTANCE_PERFORMANCE
        true
        #else
        ProcessInfo.processInfo.environment[Self.optInEnvironmentKey] == "1"
        #endif
    }
}
