import XCTest

@MainActor
final class StepBackMacUITests: XCTestCase {
    func testWelcomeSheetDismissesToSeededLibrary() {
        let app = launchApp(showWelcome: true)

        XCTAssertTrue(app.descendants(matching: .any)["welcome.screen"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["welcome.getStarted"].exists)
        app.buttons["welcome.getStarted"].click()
        XCTAssertTrue(app.descendants(matching: .any)["tab.routines"].waitForExistence(timeout: 3))
        XCTAssertTrue(seededRoutineCard(in: app).waitForExistence(timeout: 3))
    }

    func testBrowsingSidebarLaunches() {
        let app = launchApp()

        XCTAssertTrue(app.descendants(matching: .any)["tab.routines"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["tab.gallery"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["tab.settings"].exists)
        XCTAssertTrue(seededRoutineCard(in: app).exists)
    }

    func testRoutineSelectionUsesMacDetailPane() {
        let app = launchApp()
        let quickStart = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Quick Start"))
            .firstMatch

        XCTAssertTrue(quickStart.waitForExistence(timeout: 4))
        quickStart.click()

        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Select a routine"].exists)
    }

    func testSettingsReplacesBrowsingColumns() {
        let app = launchApp()
        let settings = app.descendants(matching: .any)["tab.settings"]

        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.click()

        XCTAssertTrue(app.descendants(matching: .any)["settings.voice"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Select a routine"].exists)
    }

    func testAgentBridgeSettingsCommandAndProvenance() throws {
        let bridgeRootName = "AgentBridgeUITest-\(UUID().uuidString)"
        let app = launchApp(emptyStore: true, agentBridgeRootName: bridgeRootName)

        let settings = app.descendants(matching: .any)["tab.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 4))
        settings.click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.agentBridge.toggle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.agentBridge.reveal"].exists)

        let manifestURL = try XCTUnwrap(waitForBridgeManifest(rootName: bridgeRootName, timeout: 3))
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        let inboxPath = try XCTUnwrap(manifest?["inboxPath"] as? String)
        let processedPath = try XCTUnwrap(manifest?["processedPath"] as? String)
        let commandID = "C1111111-1111-4111-8111-111111111111"
        let command = """
        {
          "schemaVersion": 1,
          "commandID": "\(commandID)",
          "verb": "createRoutine",
          "payload": {
            "name": "Agent Bridge Proof",
            "steps": [
              {"workoutID":"bridge","workSeconds":30,"sets":1,"setRestSeconds":0,"restAfterSeconds":0}
            ]
          }
        }
        """
        let commandURL = URL(fileURLWithPath: inboxPath).appendingPathComponent("001-proof.json")
        try Data(command.utf8).write(to: commandURL, options: .atomic)
        let outcomeURL = URL(fileURLWithPath: processedPath)
            .appendingPathComponent("\(commandID.lowercased()).outcome.json")
        XCTAssertTrue(waitForFile(at: outcomeURL, timeout: 4))

        app.descendants(matching: .any)["tab.routines"].click()
        let routine = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Agent Bridge Proof"))
            .firstMatch
        let routinesScrollView = app.descendants(matching: .any)["home.scroll"]
        XCTAssertTrue(routinesScrollView.waitForExistence(timeout: 2))
        for _ in 0..<3 where !routine.waitForExistence(timeout: 1) {
            routinesScrollView.swipeUp()
        }
        XCTAssertTrue(routine.waitForExistence(timeout: 2))
        routine.click()
        let hero = app.staticTexts["routineDetail.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 3))
        let provenance = app.staticTexts["detail.provenance.agent"]
        XCTAssertTrue(provenance.waitForExistence(timeout: 2))
        XCTAssertEqual(provenance.label, "Edited by agent")
    }

    func testBuilderCreatesRoutineSmoke() {
        let app = launchApp(emptyStore: true)

        let emptyNewRoutine = app.buttons["home.empty.newRoutine"]
        let toolbarNewRoutine = app.buttons["home.newRoutine"]
        let newRoutine = emptyNewRoutine.waitForExistence(timeout: 4) ? emptyNewRoutine : toolbarNewRoutine
        XCTAssertTrue(newRoutine.waitForExistence(timeout: 2))
        newRoutine.click()

        let builderSheet = app.sheets.containing(.button, identifier: "builder.save").firstMatch
        XCTAssertTrue(builderSheet.waitForExistence(timeout: 2))
        XCTAssertTrue(builderSheet.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))
        builderSheet.buttons["builder.addWorkouts"].click()
        let searchField = builderSheet.textFields["builder.picker.search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("Bridge")

        let bridgeRow = builderSheet.buttons["builder.picker.row.bridge"]
        XCTAssertTrue(bridgeRow.waitForExistence(timeout: 2))
        bridgeRow.click()
        XCTAssertTrue(builderSheet.buttons["builder.picker.add"].isEnabled)
        builderSheet.buttons["builder.picker.add"].click()

        XCTAssertTrue(builderSheet.descendants(matching: .any)["builder.step.0"].waitForExistence(timeout: 2))
        XCTAssertTrue(builderSheet.buttons["builder.save"].isEnabled)
        builderSheet.buttons["builder.save"].click()
        XCTAssertFalse(builderSheet.waitForExistence(timeout: 2))

        let bridgeStep = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == %@ AND (label CONTAINS[c] %@ OR value CONTAINS[c] %@)",
                "routineDetail.step.0",
                "Bridge",
                "Bridge"
            )
        ).firstMatch
        XCTAssertTrue(bridgeStep.waitForExistence(timeout: 3))
    }

    func testPlansSectionAndEditorOperate() {
        let app = launchApp()

        XCTAssertTrue(app.descendants(matching: .any)["plans.home.section"].waitForExistence(timeout: 4))
        let newPlan = app.buttons["New Plan"].firstMatch
        XCTAssertTrue(newPlan.waitForExistence(timeout: 2))
        newPlan.click()

        XCTAssertTrue(app.descendants(matching: .any)["plans.editor.list"].waitForExistence(timeout: 2))
        app.buttons["plans.editor.week.0.addRoutine"].click()
        XCTAssertTrue(app.buttons["Quick Start"].waitForExistence(timeout: 2))
        app.buttons["Quick Start"].click()
        XCTAssertTrue(app.buttons["plans.editor.save"].isEnabled)
        app.typeKey("s", modifierFlags: .command)

        XCTAssertTrue(app.buttons["plans.detail.activate"].waitForExistence(timeout: 3))
        app.buttons["plans.detail.activate"].click()
    }

    func testPlayerWindowKeyboardPauseAndEndConfirmation() {
        let app = launchApp()
        let play = app.buttons["Play Quick Start"]
        XCTAssertTrue(play.waitForExistence(timeout: 4))
        play.click()

        XCTAssertTrue(app.descendants(matching: .any)["player.stage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 3))
        let stageAttachment = XCTAttachment(screenshot: app.screenshot())
        stageAttachment.name = "Mac player stage"
        stageAttachment.lifetime = .keepAlways
        add(stageAttachment)
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(app.buttons["player.playPause"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["player.playPause"].label, "Resume")
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(app.buttons["player.end.confirm"].waitForExistence(timeout: 2))
    }

    func testMacEndToEndBuildPlayResizeCompleteAndShowStats() {
        let app = launchApp(emptyStore: true)

        let emptyNewRoutine = app.buttons["home.empty.newRoutine"]
        let toolbarNewRoutine = app.buttons["home.newRoutine"]
        let newRoutine = emptyNewRoutine.waitForExistence(timeout: 4) ? emptyNewRoutine : toolbarNewRoutine
        XCTAssertTrue(newRoutine.waitForExistence(timeout: 2))
        newRoutine.click()
        XCTAssertTrue(app.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))
        app.buttons["builder.addWorkouts"].click()

        let searchField = app.textFields["builder.picker.search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        searchField.typeText("Bridge")
        XCTAssertTrue(app.buttons["builder.picker.row.bridge"].waitForExistence(timeout: 2))
        app.buttons["builder.picker.row.bridge"].click()
        app.buttons["builder.picker.add"].click()
        XCTAssertTrue(app.buttons["builder.save"].waitForExistence(timeout: 2))
        app.buttons["builder.save"].click()

        XCTAssertTrue(app.buttons["routineDetail.play"].waitForExistence(timeout: 3))
        app.buttons["routineDetail.play"].click()
        XCTAssertTrue(app.descendants(matching: .any)["player.stage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 3))

        let stageWindow = app.windows.allElementsBoundByIndex.first {
            $0.descendants(matching: .any)["player.stage"].exists
        } ?? app.windows.firstMatch
        XCTAssertTrue(stageWindow.waitForExistence(timeout: 3))
        let originalFrame = stageWindow.frame
        let resizeCorner = stageWindow.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
        resizeCorner.press(
            forDuration: 0.2,
            thenDragTo: resizeCorner.withOffset(CGVector(dx: 160, dy: 120))
        )
        let resizedFrame = stageWindow.frame
        XCTAssertGreaterThan(abs(resizedFrame.width - originalFrame.width), 20)
        XCTAssertGreaterThan(abs(resizedFrame.height - originalFrame.height), 20)
        XCTAssertTrue(stageWindow.descendants(matching: .any)["player.stage"].exists)
        XCTAssertTrue(stageWindow.descendants(matching: .any)["player.playPause"].isHittable)
        XCTAssertTrue(stageWindow.descendants(matching: .any)["player.countdown"].exists)

        app.typeKey(" ", modifierFlags: [])
        XCTAssertEqual(app.buttons["player.playPause"].label, "Resume")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        app.typeKey(" ", modifierFlags: [])
        expectation(
            for: NSPredicate(format: "label == %@", "Pause"),
            evaluatedWith: app.buttons["player.playPause"]
        )
        waitForExpectations(timeout: 7)
        app.typeKey(XCUIKeyboardKey.rightArrow.rawValue, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: [])

        for _ in 0..<8 where app.descendants(matching: .any)["player.skip"].exists {
            app.typeKey(XCUIKeyboardKey.rightArrow.rawValue, modifierFlags: [])
        }
        XCTAssertTrue(app.staticTexts["player.complete.minutes"].waitForExistence(timeout: 3))
        app.buttons["player.complete.done"].click()

        XCTAssertTrue(app.descendants(matching: .any)["tab.routines"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Last done Today · 1×"))
                .firstMatch
                .waitForExistence(timeout: 3)
        )
    }

    private func launchApp(
        emptyStore: Bool = false,
        showWelcome: Bool = false,
        agentBridgeRootName: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-StepBackUITesting")
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        if emptyStore {
            app.launchEnvironment["StepBackUIEmptyStore"] = "1"
        }
        if showWelcome {
            app.launchEnvironment["StepBackUIShowWelcome"] = "1"
        }
        if let agentBridgeRootName {
            app.launchEnvironment["StepBackUIAgentBridgeRootName"] = agentBridgeRootName
        }
        app.launch()

        ensureWindow(for: app)
        return app
    }

    private func waitForFile(at url: URL, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func waitForBridgeManifest(rootName: String, timeout: TimeInterval) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(
                "Library/Containers/com.nags.stepback/Data/Library/Application Support/\(rootName)/manifest.json"
            ),
            home.appendingPathComponent("Library/Application Support/\(rootName)/manifest.json")
        ]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let match = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                return match
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
    }

    private func seededRoutineCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.card."))
            .firstMatch
    }

    private func ensureWindow(for app: XCUIApplication) {
        let window = app.windows.firstMatch
        if window.waitForExistence(timeout: 3) {
            return
        }

        for _ in 0..<3 {
            app.activate()
            if window.waitForExistence(timeout: 1) {
                return
            }

            let fileMenu = app.menuBars.menuBarItems["File"]
            if fileMenu.waitForExistence(timeout: 2) {
                fileMenu.click()
                let newWindow = app.menuItems["New Window"]
                if newWindow.waitForExistence(timeout: 2) {
                    newWindow.click()
                }
            }

            if window.waitForExistence(timeout: 3) {
                return
            }
        }

        XCTAssertTrue(window.waitForExistence(timeout: 4))
    }
}
