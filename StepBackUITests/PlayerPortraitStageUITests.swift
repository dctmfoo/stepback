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
        if !play.exists {
            app.swipeDown()
        }
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()

        let skip = app.descendants(matching: .any)["player.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 2))
        advance(toKickerContaining: "work", using: skip, in: app)

        let countdown = app.descendants(matching: .any)["player.countdown"]
        let name = app.descendants(matching: .any)["player.name"]
        let visual = app.descendants(matching: .any)["player.visual.category"]
        let kicker = app.descendants(matching: .any)["player.kicker"]
        let detail = app.descendants(matching: .any)["player.setIndicator"]
        let controls = controlElements(in: app)
        XCTAssertTrue(countdown.waitForExistence(timeout: 2))
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertTrue(visual.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.progress"].exists)
        XCTAssertTrue(controls.allSatisfy(\.exists))
        XCTAssertTrue(detail.exists)
        waitForStableLayout([kicker, countdown, name, detail, visual] + controls)
        assertCentered([kicker, countdown, name, detail, visual], in: app)
        assertPortraitVisualBudget(visual, in: app)

        let countdownFrameBeforeNext = countdown.frame
        let visualFrameBeforeNext = visual.frame
        let nextDuringWork = app.descendants(matching: .any)["player.next"]
        XCTAssertFalse(nextDuringWork.exists)
        XCTAssertTrue(
            nextDuringWork.waitForExistence(timeout: 60),
            "Next-up must appear during the final five seconds of work"
        )
        let playPause = app.descendants(matching: .any)["player.playPause"]
        playPause.tap()
        let paused = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return element.exists && element.label.localizedCaseInsensitiveContains("resume")
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: paused, object: playPause)],
                timeout: 2
            ),
            .completed,
            "The final-five work state must be frozen before rotation checks"
        )
        waitForStableLayout([countdown, visual, nextDuringWork] + controls)
        XCTAssertTrue(detail.exists, "Work detail must remain visible beside final-five next-up")
        assertStablePosition(
            countdown,
            from: countdownFrameBeforeNext,
            accuracy: 2,
            message: "Countdown must not move when final-five next-up appears"
        )
        assertStablePosition(
            visual,
            from: visualFrameBeforeNext,
            accuracy: 2,
            message: "Workout visual must not move when final-five next-up appears"
        )
        assertWithinStage(
            [kicker, countdown, name, detail, nextDuringWork, visual] + controls,
            in: app
        )
        XCTAssertGreaterThanOrEqual(
            visual.frame.minY - nextDuringWork.frame.maxY,
            20,
            "The visual must remain a separately budgeted band below the hero"
        )
        attachScreenshot(named: "iPad portrait work", from: app)

        let portraitFrame = app.windows.firstMatch.frame
        let runsIPadLandscapeRegression = portraitFrame.width >= 700
        if runsIPadLandscapeRegression {
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForWindow(in: app, toBeLandscape: true, differingFrom: portraitFrame)
            waitForStableLayout([countdown, name, detail, nextDuringWork, visual] + controls)
            assertWideComposition(
                hero: [countdown, name, detail, nextDuringWork],
                visual: visual
            )
            assertWithinStage(
                [countdown, name, detail, nextDuringWork, visual] + controls,
                in: app
            )
            attachScreenshot(named: "iPad landscape work regression", from: app)

            let landscapeFrame = app.windows.firstMatch.frame
            XCUIDevice.shared.orientation = .portrait
            waitForWindow(in: app, toBeLandscape: false, differingFrom: landscapeFrame)
            waitForStableLayout([countdown, name, detail, nextDuringWork, visual] + controls)
        }

        advance(toKickerContaining: "rest", using: skip, in: app)
        let next = app.descendants(matching: .any)["player.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 2))
        waitForStableLayout([kicker, next, countdown, detail, visual] + controls)
        assertCentered([kicker, next, countdown, detail, visual], in: app)
        assertPortraitVisualBudget(visual, in: app)
        assertWithinStage([kicker, next, countdown, detail, visual] + controls, in: app)
        attachScreenshot(named: "iPad portrait rest", from: app)

        if runsIPadLandscapeRegression {
            let restPortraitFrame = app.windows.firstMatch.frame
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForWindow(in: app, toBeLandscape: true, differingFrom: restPortraitFrame)
            waitForStableLayout([next, countdown, detail, visual] + controls)
            assertWideComposition(hero: [next, countdown, detail], visual: visual)
            assertWithinStage(
                [next, countdown, detail, visual] + controls,
                in: app
            )
            attachScreenshot(named: "iPad landscape regression", from: app)
        }
    }

    func testStackedPlayerYieldsForAccessibilityText() {
        XCUIDevice.shared.orientation = .portrait
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }

        let app = XCUIApplication()
        app.launchArguments += [
            "-StepBackUITesting",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launchEnvironment["StepBackUIAccessibilityXXXL"] = "1"
        app.launchEnvironment["StepBackUILongWorkoutNameFixture"] = "1"
        app.launch()

        let play = app.buttons["Play Quick Start"]
        if !play.exists {
            app.swipeDown()
        }
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()

        let skip = app.descendants(matching: .any)["player.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 2))
        advance(toKickerContaining: "work", using: skip, in: app)

        let kicker = app.descendants(matching: .any)["player.kicker"]
        let countdown = app.descendants(matching: .any)["player.countdown"]
        let name = app.descendants(matching: .any)["player.name"]
        let detail = app.descendants(matching: .any)["player.setIndicator"]
        let visual = app.descendants(matching: .any)["player.visual.category"]
        let progress = app.descendants(matching: .any)["player.progress"]
        let controls = controlElements(in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 2))
        XCTAssertTrue(name.label.contains("Alternating Single Leg Squat"))
        waitForStableLayout([kicker, countdown, name, detail, visual, progress] + controls)
        assertCentered([kicker, countdown, name, detail, visual], in: app)
        assertWithinStage(
            [kicker, countdown, name, detail, visual, progress] + controls,
            in: app
        )
        XCTAssertLessThanOrEqual(
            visual.frame.maxY + 12,
            progress.frame.minY,
            "The compressed visual must remain above progress; visual=\(visual.frame), progress=\(progress.frame)"
        )
        attachScreenshot(named: "Stacked player AX-XXXL long name", from: app)
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
            let previousLabel = kicker.exists ? kicker.label : ""
            skip.tap()
            let changed = NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                return element.exists && element.label != previousLabel
            }
            let expectation = XCTNSPredicateExpectation(predicate: changed, object: kicker)
            _ = XCTWaiter.wait(for: [expectation], timeout: 2)
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

    private func assertStablePosition(
        _ element: XCUIElement,
        from originalFrame: CGRect,
        accuracy: CGFloat,
        message: String
    ) {
        XCTAssertEqual(element.frame.midX, originalFrame.midX, accuracy: accuracy, message)
        XCTAssertEqual(element.frame.minY, originalFrame.minY, accuracy: accuracy, message)
    }

    private func assertPortraitVisualBudget(_ visual: XCUIElement, in app: XCUIApplication) {
        XCTAssertEqual(
            visual.frame.width / visual.frame.height,
            4 / 3,
            accuracy: 0.05,
            "The stacked WorkoutVisual must preserve its 4:3 region"
        )
        let heightFraction = visual.frame.height / app.windows.firstMatch.frame.height
        XCTAssertTrue(
            (0.24...0.36).contains(heightFraction),
            "The stacked WorkoutVisual must consume roughly 30% of the stage height"
        )
    }

    private func assertWideComposition(hero: [XCUIElement], visual: XCUIElement) {
        for element in hero {
            XCTAssertLessThan(
                element.frame.midX,
                visual.frame.midX,
                "\(element.identifier) must remain in the leading landscape column"
            )
        }
        XCTAssertGreaterThan(
            visual.frame.midX - hero.map(\.frame.midX).max()!,
            120,
            "Landscape must retain visibly separate hero and visual columns"
        )
    }

    private func controlElements(in app: XCUIApplication) -> [XCUIElement] {
        ["player.back", "player.playPause", "player.skip", "player.end"].map {
            app.descendants(matching: .any)[$0]
        }
    }

    private func waitForWindow(
        in app: XCUIApplication,
        toBeLandscape: Bool,
        differingFrom originalFrame: CGRect,
        timeout: TimeInterval = 3
    ) {
        let window = app.windows.firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let frame = window.frame
            let matchesOrientation = toBeLandscape
                ? frame.width > frame.height
                : frame.height > frame.width
            if matchesOrientation && frame != originalFrame { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTFail("Player window did not settle into the expected orientation")
    }

    private func assertWithinStage(_ elements: [XCUIElement], in app: XCUIApplication) {
        let stageFrame = app.windows.firstMatch.frame
        for element in elements {
            XCTAssertTrue(element.exists, "\(element.identifier) must exist")
            XCTAssertFalse(element.frame.isEmpty, "\(element.identifier) must have a visible frame")
            XCTAssertTrue(
                stageFrame.insetBy(dx: -2, dy: -2).contains(element.frame),
                "\(element.identifier) must remain inside the stage"
            )
        }
    }

    private func attachScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForStableLayout(
        _ elements: [XCUIElement],
        timeout: TimeInterval = 2
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        var previousFrames: [CGRect]?
        var stableSamples = 0

        repeat {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            let frames = elements.map(\.frame)
            if frames == previousFrames {
                stableSamples += 1
                if stableSamples == 2 { return }
            } else {
                stableSamples = 0
                previousFrames = frames
            }
        } while Date() < deadline

        XCTFail("Player layout did not settle within \(timeout) seconds")
    }
}
