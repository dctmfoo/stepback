import XCTest

@MainActor
final class PlayerPortraitStageUITests: XCTestCase {
    func testPortraitPlayerKeepsWorkAndRestOnOneCenterAxis() {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }

        let app = XCUIApplication()
        app.launchArguments.append("-StepBackUITesting")
        app.launch()

        let play = app.buttons["Play Quick Start"]
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()

        let skip = app.descendants(matching: .any)["player.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 2))
        advance(toKickerContaining: "work", using: skip, in: app)

        let countdown = app.descendants(matching: .any)["player.countdown"]
        let name = app.descendants(matching: .any)["player.name"]
        let visual = app.descendants(matching: .any)["player.visual.category"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 2))
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertTrue(visual.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.progress"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].exists)
        assertCentered([countdown, name, visual], in: app)
        waitForLayoutToSettle()
        attachScreenshot(named: "iPad portrait work", from: app)

        advance(toKickerContaining: "rest", using: skip, in: app)
        let next = app.descendants(matching: .any)["player.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        assertCentered([next, countdown], in: app)
        waitForLayoutToSettle()
        attachScreenshot(named: "iPad portrait rest", from: app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["player.progress"].waitForExistence(timeout: 2))
        waitForLayoutToSettle()
        attachScreenshot(named: "iPad landscape regression", from: app)
    }

    private func advance(
        toKickerContaining expected: String,
        using skip: XCUIElement,
        in app: XCUIApplication
    ) {
        let kicker = app.descendants(matching: .any)["player.kicker"]
        for _ in 0..<6 {
            if kicker.exists,
               kicker.label.localizedCaseInsensitiveContains(expected) {
                return
            }
            skip.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTFail("Player did not reach the expected \(expected) segment")
    }

    private func assertCentered(_ elements: [XCUIElement], in app: XCUIApplication) {
        let stageMidX = app.windows.firstMatch.frame.midX
        for element in elements {
            XCTAssertEqual(
                element.frame.midX,
                stageMidX,
                accuracy: 12,
                "\(element.identifier) must share the portrait stage center axis"
            )
        }
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForLayoutToSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }
}
