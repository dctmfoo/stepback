import XCTest

@MainActor
final class StepBackUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launchApp(
        emptyStore: Bool = false,
        showWelcome: Bool = false,
        removedPlanFixture: Bool = false
    ) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-StepBackUITesting")
        if emptyStore {
            app.launchEnvironment["StepBackUIEmptyStore"] = "1"
        }
        if showWelcome {
            app.launchEnvironment["StepBackUIShowWelcome"] = "1"
        }
        if removedPlanFixture {
            app.launchEnvironment["StepBackUIRemovedPlanFixture"] = "1"
        }
        app.launch()
    }

    func testWelcomeGetsToAStarterPlayerInTwoHomeTaps() {
        launchApp(showWelcome: true)

        XCTAssertTrue(app.descendants(matching: .any)["welcome.screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Build your routine once. Then press play, step back, and follow."].exists)
        XCTAssertTrue(app.staticTexts["Compose"].exists)
        XCTAssertTrue(app.staticTexts["Play"].exists)
        XCTAssertTrue(app.staticTexts["Follow"].exists)
        app.buttons["welcome.getStarted"].tap()

        XCTAssertTrue(app.staticTexts["Quick Start"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Full-Body Classic"].exists)
        XCTAssertTrue(app.staticTexts["The Full Session"].exists)
        app.buttons["Play Quick Start"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.stage"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 2))
    }

    func testBrowsingShellAndRoutineDetail() {
        launchApp()
        assertTabBar()
        XCTAssertTrue(app.staticTexts["The Full Session"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Full-Body Classic"].exists)
        XCTAssertTrue(app.staticTexts["Quick Start"].exists)
        XCTAssertGreaterThanOrEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Not played yet")).count,
            3
        )
        XCTAssertFalse(app.otherElements["home.motivationStrip"].exists)
        XCTAssertTrue(app.buttons["Play Quick Start"].exists)

        let routineCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Quick Start ·")
        ).firstMatch
        XCTAssertTrue(routineCard.waitForExistence(timeout: 2))
        routineCard.tap()

        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["routineDetail.play"].exists)
        XCTAssertTrue(app.buttons["detail.edit"].exists)
        XCTAssertTrue(app.buttons["routineDetail.duplicate"].exists)
        XCTAssertTrue(app.buttons["routineDetail.delete"].exists)
        let firstStep = app.descendants(matching: .any)["routineDetail.step.0"]
        XCTAssertTrue(firstStep.exists)
        XCTAssertFalse(firstStep.label.isEmpty)
        XCTAssertTrue(app.descendants(matching: .any)["routineDetail.rest.0"].exists)

        app.buttons["detail.edit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["builder.step.0"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["builder.save"].exists)
        app.buttons["builder.cancel"].tap()
        XCTAssertTrue(app.buttons["routineDetail.delete"].waitForExistence(timeout: 2))

        app.buttons["routineDetail.delete"].tap()
        app.sheets.buttons["Delete Routine"].tap()
        XCTAssertTrue(app.staticTexts["Quick Start"].waitForNonExistence(timeout: 2))
    }

    func testRoutineBuilderCreatesRoutineFromHome() {
        launchApp(emptyStore: true)

        XCTAssertTrue(app.buttons["home.empty.newRoutine"].waitForExistence(timeout: 2))
        app.buttons["home.empty.newRoutine"].tap()
        XCTAssertTrue(app.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["builder.save"].isEnabled)

        app.buttons["builder.addWorkouts"].tap()
        selectPickerWorkout(id: "bridge", search: "Bridge")
        XCTAssertTrue(app.descendants(matching: .any)["builder.picker.tray"].exists)
        selectPickerWorkout(id: "squat", search: "Squat")
        selectPickerWorkout(id: "russian-twist", search: "Russian")
        selectPickerWorkout(id: "bicycle-crunch", search: "Bicycle")
        selectPickerWorkout(id: "mountain-climber", search: "Mountain")
        XCTAssertTrue(app.buttons["builder.picker.add"].isEnabled)
        app.buttons["builder.picker.add"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["builder.step.0"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["builder.step.1"].exists)
        assertBuilderTotal("3 minutes, 30 seconds")

        expandBuilderStep(0)
        incrementStepper("builder.step.0.sets", times: 2)
        incrementStepper("builder.step.0.setRest", times: 2)
        assertBuilderTotal("4 minutes, 50 seconds")
        expandBuilderStep(1)
        incrementStepper("builder.step.1.sets")
        assertBuilderTotal("5 minutes, 20 seconds")
        expandBuilderStep(2)
        incrementStepper("builder.step.2.restAfter")
        assertBuilderTotal("5 minutes, 25 seconds")
        expandBuilderStep(3)
        incrementStepper("builder.step.3.repGuidance", times: 4)
        assertBuilderTotal("5 minutes, 25 seconds")
        incrementStepper("builder.step.3.restAfter")

        assertBuilderTotal("5 minutes, 30 seconds", retryingIncrement: "builder.step.3.restAfter")
        let collapsedRest = app.descendants(matching: .any)["builder.step.0.rest"]
        waitForLazyElement(collapsedRest, direction: .up)
        XCTAssertTrue(collapsedRest.exists)
        XCTAssertTrue(app.buttons["builder.save"].isEnabled)
        app.buttons["builder.save"].tap()

        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["routineDetail.hero"].label, "5 minutes, 30 seconds")
        XCTAssertTrue(app.staticTexts["Bridge"].exists)
        XCTAssertTrue(app.staticTexts["Squat"].exists)
        XCTAssertTrue(app.staticTexts["Russian Twist"].exists)
        XCTAssertTrue(app.staticTexts["Bicycle Crunch"].exists)
        XCTAssertTrue(app.staticTexts["Mountain Climber"].exists)
    }

    func testRoutineBuilderReorderCarriesRestRowAndKeepsTotal() {
        launchApp(emptyStore: true)

        XCTAssertTrue(app.buttons["home.empty.newRoutine"].waitForExistence(timeout: 2))
        app.buttons["home.empty.newRoutine"].tap()
        XCTAssertTrue(app.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))

        app.buttons["builder.addWorkouts"].tap()
        selectPickerWorkout(id: "bridge", search: "Bridge")
        selectPickerWorkout(id: "squat", search: "Squat")
        selectPickerWorkout(id: "russian-twist", search: "Russian")
        app.buttons["builder.picker.add"].tap()

        expandBuilderStep(0)
        incrementStepper("builder.step.0.restAfter")
        assertBuilderTotal("2 minutes, 5 seconds")
        app.descendants(matching: .any)["builder.step.0"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["builder.step.0.rest"].waitForExistence(timeout: 2))

        let actions = app.buttons["builder.step.0.actions"]
        scrollToElement(actions)
        actions.tap()
        let moveDown = app.buttons["Move Down"]
        XCTAssertTrue(moveDown.waitForExistence(timeout: 2))
        moveDown.tap()

        let movedRest = app.buttons["builder.step.1.rest"]
        XCTAssertTrue(movedRest.waitForExistence(timeout: 2))
        XCTAssertTrue(movedRest.label.contains("20 seconds"))
        assertBuilderTotal("2 minutes, 5 seconds")
    }

    func testRoutineBuilderEditSaveAndCancelIsolation() {
        launchApp()

        XCTAssertTrue(app.staticTexts["Quick Start"].waitForExistence(timeout: 3))
        app.staticTexts["Quick Start"].tap()
        let originalHero = app.staticTexts["routineDetail.hero"]
        XCTAssertTrue(originalHero.waitForExistence(timeout: 2))
        let originalDuration = originalHero.label

        app.buttons["detail.edit"].tap()
        expandBuilderStep(0)
        incrementStepper("builder.step.0.work")
        app.buttons["builder.cancel"].tap()
        tapDiscardChanges()
        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["routineDetail.hero"].label, originalDuration)

        app.buttons["detail.edit"].tap()
        expandBuilderStep(0)
        incrementStepper("builder.step.0.work")
        app.buttons["builder.save"].tap()

        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 2))
        XCTAssertNotEqual(app.staticTexts["routineDetail.hero"].label, originalDuration)
    }

    func testRoutineBuilderDirtyDiscardBlocksSwipeDismiss() {
        launchApp(emptyStore: true)

        XCTAssertTrue(app.buttons["home.empty.newRoutine"].waitForExistence(timeout: 2))
        app.buttons["home.empty.newRoutine"].tap()
        XCTAssertTrue(app.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))
        app.buttons["builder.addWorkouts"].tap()
        selectPickerWorkout(id: "bridge", search: "Bridge")
        app.buttons["builder.picker.add"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["builder.step.0"].waitForExistence(timeout: 2))
        app.swipeDown()
        XCTAssertTrue(app.buttons["builder.cancel"].waitForExistence(timeout: 2))
        app.buttons["builder.cancel"].tap()
        tapDiscardChanges()
        XCTAssertTrue(app.buttons["home.empty.newRoutine"].waitForExistence(timeout: 2))
    }

    func testGalleryNewRoutineSeedsBuilderWithWorkout() {
        launchApp()
        tab("tab.gallery").tap()
        search(for: "Bridge")
        let bridgeTile = app.descendants(matching: .any)["gallery.tile.bridge"]
        XCTAssertTrue(bridgeTile.waitForExistence(timeout: 2))
        bridgeTile.tap()

        XCTAssertTrue(app.buttons["workoutDetail.addToRoutine"].waitForExistence(timeout: 2))
        app.buttons["workoutDetail.addToRoutine"].tap()
        XCTAssertTrue(app.buttons["addToRoutine.newRoutine"].waitForExistence(timeout: 2))
        app.buttons["addToRoutine.newRoutine"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["builder.step.0"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Bridge"].exists)
        XCTAssertTrue(app.buttons["builder.save"].isEnabled)
        app.buttons["builder.save"].tap()

        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Bridge"].exists)
    }

    func testGallerySearchAddAndCustomWorkoutSnapshotLifecycle() {
        launchApp()
        tab("tab.gallery").tap()
        revealSearchField()
        XCTAssertTrue(app.descendants(matching: .any)["gallery.search"].exists)
        XCTAssertTrue(app.staticTexts["Full Body"].exists)

        search(for: "Bridge")
        let bridgeTile = app.descendants(matching: .any)["gallery.tile.bridge"]
        XCTAssertTrue(bridgeTile.waitForExistence(timeout: 2))
        XCTAssertTrue(bridgeTile.label.contains("Bridge"))
        app.descendants(matching: .any)["gallery.tile.bridge"].tap()
        XCTAssertTrue(app.buttons["workoutDetail.addToRoutine"].waitForExistence(timeout: 2))
        app.buttons["workoutDetail.addToRoutine"].tap()
        XCTAssertTrue(app.staticTexts["Quick Start"].waitForExistence(timeout: 2))
        app.staticTexts["Quick Start"].tap()

        app.terminate()
        app.launch()
        tab("tab.gallery").tap()
        let addCustom = app.buttons.matching(identifier: "gallery.addCustom").firstMatch
        XCTAssertTrue(addCustom.waitForExistence(timeout: 2))
        addCustom.tap()
        XCTAssertTrue(app.textFields["customEditor.name"].waitForExistence(timeout: 2))
        app.textFields["customEditor.name"].tap()
        app.textFields["customEditor.name"].typeText("Wall Sit")
        scrollToElement(app.buttons["customEditor.category.legs-glutes"])
        app.buttons["customEditor.category.legs-glutes"].tap()
        app.buttons["customEditor.save"].tap()

        revealSearchField()
        search(for: "Wall Sit")
        app.staticTexts["Wall Sit"].tap()
        XCTAssertTrue(app.buttons["workoutDetail.edit"].waitForExistence(timeout: 2))
        app.buttons["workoutDetail.addToRoutine"].tap()
        app.staticTexts["Quick Start"].tap()

        XCTAssertTrue(app.buttons["workoutDetail.delete"].waitForExistence(timeout: 2))
        app.buttons["workoutDetail.delete"].tap()
        app.sheets.buttons["Delete Workout"].tap()

        if app.frame.width > 600 {
            XCTAssertTrue(
                app.staticTexts
                    .matching(NSPredicate(format: "label BEGINSWITH %@", "No Results"))
                    .firstMatch
                    .waitForExistence(timeout: 2)
            )
            return
        }

        tab("tab.routines").tap()
        app.staticTexts["Quick Start"].tap()
        XCTAssertTrue(app.staticTexts["Wall Sit"].waitForExistence(timeout: 2))
    }

    func testEmptyStoreRestoresStarters() {
        launchApp(emptyStore: true)

        XCTAssertTrue(app.staticTexts["No routines yet"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["home.empty.newRoutine"].exists)
        XCTAssertTrue(app.buttons["home.empty.restore"].exists)
        app.buttons["home.empty.restore"].tap()

        XCTAssertTrue(app.staticTexts["Quick Start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Full-Body Classic"].exists)
        XCTAssertTrue(app.staticTexts["The Full Session"].exists)
    }

    func testPlayerSettingsAreAvailable() {
        launchApp()
        tab("tab.settings").tap()

        XCTAssertTrue(app.switches["settings.voice"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["settings.tones"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.getReady"].exists)
        let sync = app.descendants(matching: .any)["settings.sync"]
        XCTAssertTrue(sync.waitForExistence(timeout: 2))
        XCTAssertTrue(sync.label.contains("Up to date"))
    }

    func testWeeklyPlanFirstSaveShowsTodayAndAdHocCompletionMarksDone() {
        launchApp()

        let nudge = app.buttons["plans.nudge.row"]
        waitForLazyElement(nudge, direction: .down)
        nudge.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plans.editor.list"].waitForExistence(timeout: 2))

        let weekday = Calendar.current.component(.weekday, from: Date())
        let addRoutine = app.buttons["plans.editor.day.\(weekday).addRoutine"]
        waitForLazyElement(addRoutine, direction: .down)
        addRoutine.tap()
        XCTAssertTrue(app.buttons["Quick Start"].waitForExistence(timeout: 2))
        app.buttons["Quick Start"].tap()
        app.buttons["plans.editor.save"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["plans.overview.list"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["My Week"].exists)
        app.navigationBars.buttons["Routines"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["plans.today.card"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Quick Start"].exists)

        // Start from the ordinary routine card to prove plan completion is derived
        // from session history rather than a plan-launch cursor.
        app.buttons["Play Quick Start"].tap()
        XCTAssertTrue(playerElement("player.skip").waitForExistence(timeout: 2))
        for _ in 0..<36 where playerElement("player.skip").exists {
            playerElement("player.skip").tap()
        }
        XCTAssertTrue(app.staticTexts["player.complete.minutes"].waitForExistence(timeout: 3))
        app.buttons["player.complete.done"].tap()

        XCTAssertTrue(app.staticTexts["Done for Today"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["plans.today.play"].exists)
    }

    func testWeeklyPlanRestDayAndMyWeekSelection() {
        launchApp()

        let nudge = app.buttons["plans.nudge.row"]
        waitForLazyElement(nudge, direction: .down)
        nudge.tap()
        app.buttons["plans.editor.save"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["plans.overview.list"].waitForExistence(timeout: 3))
        app.buttons["Duplicate Plan"].tap()
        XCTAssertTrue(app.buttons["Plans"].waitForExistence(timeout: 2))
        app.buttons["Plans"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["plans.picker.list"].waitForExistence(timeout: 2))
        app.staticTexts["Plan 1 copy"].tap()
        XCTAssertTrue(app.buttons["plans.myWeek.set"].waitForExistence(timeout: 2))
        app.buttons["plans.myWeek.set"].tap()
        app.navigationBars.buttons["Plans"].tap()
        app.navigationBars.buttons["Plan 1"].tap()
        app.navigationBars.buttons["Routines"].tap()

        XCTAssertTrue(app.staticTexts["Rest Day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["plans.today.repair"].exists)
        XCTAssertTrue(app.buttons["plans.myWeek.row"].label.contains("Plan 1 copy"))
    }

    func testWeeklyPlanRemovedRoutineOffersRepair() {
        launchApp(removedPlanFixture: true)

        let repair = app.buttons["plans.today.repair"]
        waitForLazyElement(repair, direction: .up)
        repair.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plans.editor.list"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Routine removed"].exists)
    }

    func testPlayerPauseBackSkipAndPartialEnd() {
        launchApp()

        let play = app.buttons["Play Quick Start"]
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()

        XCTAssertTrue(app.descendants(matching: .any)["player.stage"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.countdown"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["player.progress"].exists)
        let stageAttachment = XCTAttachment(screenshot: app.screenshot())
        stageAttachment.name = "Player stage"
        stageAttachment.lifetime = .keepAlways
        add(stageAttachment)

        let playPause = playerElement("player.playPause")
        playPause.tap()
        expectation(
            for: NSPredicate(format: "label == %@", "Resume"),
            evaluatedWith: playPause
        )
        waitForExpectations(timeout: 2)
        playerElement("player.back").tap()
        playerElement("player.skip").tap()
        playerElement("player.skip").tap()
        playerElement("player.end").tap()

        XCTAssertTrue(app.buttons["player.end.confirm"].waitForExistence(timeout: 2))
        app.buttons["player.end.confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["player.partial.message"].waitForExistence(timeout: 2))
        app.buttons["player.complete.done"].tap()
        XCTAssertTrue(app.buttons["Play Quick Start"].waitForExistence(timeout: 2))
    }

    func testPlayerCanSkipThroughToCompletionAndDismiss() {
        launchApp()
        XCTAssertTrue(app.buttons["Play Quick Start"].waitForExistence(timeout: 3))
        app.buttons["Play Quick Start"].tap()
        XCTAssertTrue(playerElement("player.skip").waitForExistence(timeout: 2))

        for _ in 0..<24 where playerElement("player.skip").exists {
            playerElement("player.skip").tap()
        }

        XCTAssertTrue(app.staticTexts["player.complete.minutes"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["player.complete.streak"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["player.complete.times"].exists)
        XCTAssertTrue(app.buttons["player.complete.goAgain"].exists)
        app.buttons["player.complete.done"].tap()
        XCTAssertTrue(app.buttons["Play Quick Start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["home.motivationStrip"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", "Last done Today · 1×"))
                .firstMatch
                .waitForExistence(timeout: 2)
        )
    }

    private func assertTabBar() {
        XCTAssertTrue(tab("tab.routines").waitForExistence(timeout: 3))
        XCTAssertTrue(tab("tab.gallery").exists)
        XCTAssertTrue(tab("tab.settings").exists)
    }

    private func playerElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func tab(_ identifier: String) -> XCUIElement {
        let matches = app.buttons.matching(identifier: identifier)
        let nestedItem = matches.element(boundBy: 1)
        return nestedItem.exists ? nestedItem : matches.firstMatch
    }

    private func search(for query: String) {
        let searchField = revealSearchField()
        searchField.tap()
        if let current = searchField.value as? String,
           !current.isEmpty,
           !current.hasPrefix("Search ") {
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        searchField.typeText(query)
    }

    @discardableResult
    private func revealSearchField() -> XCUIElement {
        let searchField = app.searchFields.firstMatch
        if !searchField.exists {
            let searchButton = app.buttons["Search"]
            XCTAssertTrue(searchButton.waitForExistence(timeout: 2))
            searchButton.tap()
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        return searchField
    }

    private func scrollToElement(_ element: XCUIElement) {
        for _ in 0..<8 where !element.isHittable {
            if element.exists, !element.frame.isEmpty, element.frame.midY < app.frame.midY {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        for _ in 0..<3 where element.isHittable && element.frame.maxY > app.frame.maxY - 120 {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func incrementStepper(_ identifier: String, times: Int = 1) {
        let stepper = app.steppers[identifier]
        XCTAssertTrue(stepper.waitForExistence(timeout: 2))
        scrollToElement(stepper)
        let increment = stepper.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5))
        for _ in 0..<times {
            increment.tap()
        }
    }

    private enum LazyElementSearchDirection {
        case up
        case down
    }

    private func expandBuilderStep(_ index: Int) {
        let workStepper = app.steppers["builder.step.\(index).work"]
        if workStepper.exists {
            return
        }

        let row = app.descendants(matching: .any)["builder.step.\(index)"]
        waitForLazyElement(row, direction: index == 0 ? .up : .down)
        scrollToElement(row)
        if workStepper.exists {
            return
        }
        let button = app.buttons["builder.step.\(index)"]
        if button.exists {
            scrollToElement(button)
            button.tap()
        } else {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5)).tap()
        }
        waitForLazyElement(workStepper, direction: .down)
    }

    private func selectPickerWorkout(id: String, search query: String) {
        setPickerSearch(query)
        let row = app.buttons["builder.picker.row.\(id)"]
        waitForLazyElement(row, direction: .down)
        row.tap()
    }

    private func waitForLazyElement(_ element: XCUIElement, direction: LazyElementSearchDirection) {
        if element.waitForExistence(timeout: 2) {
            return
        }

        let primarySwipe: () -> Void = direction == .down ? app.swipeUp : app.swipeDown
        let fallbackSwipe: () -> Void = direction == .down ? app.swipeDown : app.swipeUp

        for _ in 0..<8 where !element.exists {
            primarySwipe()
            if element.waitForExistence(timeout: 0.5) {
                return
            }
        }

        for _ in 0..<8 where !element.exists {
            fallbackSwipe()
            if element.waitForExistence(timeout: 0.5) {
                return
            }
        }

        XCTAssertTrue(element.waitForExistence(timeout: 2))
    }

    private func setPickerSearch(_ query: String) {
        let searchField = app.textFields["builder.picker.search"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        if let current = searchField.value as? String,
           !current.isEmpty,
           !current.hasPrefix("Search") {
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        searchField.typeText(query)
    }

    private func assertBuilderTotal(_ expectedValue: String, retryingIncrement identifier: String? = nil) {
        if currentBuilderTotal() != expectedValue, let identifier {
            incrementStepper(identifier)
        }
        XCTAssertEqual(currentBuilderTotal(), expectedValue)
    }

    private func currentBuilderTotal() -> String? {
        let total = app.descendants(matching: .any)["builder.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 2))
        return total.value as? String
    }

    private func tapDiscardChanges() {
        let discard = app.buttons.matching(identifier: "builder.discard.confirm").firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 2))
        discard.tap()
    }
}
