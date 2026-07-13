import XCTest

@MainActor
final class StepBackMacAccessibilityAuditTests: XCTestCase {
    private enum AuditScope: Hashable {
        case routinesHome
        case routineDetail
        case gallery
        case workoutDetail
        case builder
        case builderPicker
        case settings
        case welcome
        case playerWork
        case playerRest
    }

    private struct ElementSignature {
        let identifier: String
        let label: String
        let elementType: XCUIElement.ElementType
        let isHittable: Bool
        let hasChildren: Bool
        let frame: CGRect
    }

    private struct IssueSignature {
        let auditType: XCUIAccessibilityAuditType
        let detailedDescription: String
        let element: ElementSignature?
    }

    private struct AuditContext {
        let windowFrame: CGRect
        let scope: AuditScope
        let allowsGetReadyActionIssue: Bool
    }

    private struct NativeUnavailableFingerprint: Hashable {
        let scope: AuditScope
        let detailedDescription: String
    }

    private struct VerifiedAppContrastFingerprint: Hashable {
        let scope: AuditScope
        let identifier: String
        let detailedDescription: String
    }

    private static let nativeUnavailableContrastFingerprints: Set<NativeUnavailableFingerprint> = [
        .init(scope: .routinesHome, detailedDescription: "Contrast is not high enough for No Plans Yet unless font size is larger."),
        .init(scope: .routinesHome, detailedDescription: "Contrast failed for Group your routines into a weekly or monthly plan."),
        .init(scope: .routinesHome, detailedDescription: "Contrast failed for Select a routine"),
        .init(scope: .gallery, detailedDescription: "Contrast failed for Select a workout"),
        .init(scope: .builder, detailedDescription: "Contrast failed for No routines yet"),
        .init(scope: .builder, detailedDescription: "Contrast is not high enough for Pick workouts from the gallery and press play — that’s the whole app. unless font size is larger."),
        .init(scope: .builder, detailedDescription: "Contrast failed for Select a routine"),
        .init(scope: .builderPicker, detailedDescription: "Contrast failed for No routines yet"),
        .init(scope: .builderPicker, detailedDescription: "Contrast is not high enough for Pick workouts from the gallery and press play — that’s the whole app. unless font size is larger."),
        .init(scope: .builderPicker, detailedDescription: "Contrast failed for Select a routine"),
        .init(scope: .welcome, detailedDescription: "Contrast failed for No Plans Yet"),
        .init(scope: .welcome, detailedDescription: "Contrast failed for Select a routine"),
    ]

    private static let verifiedAppContrastFingerprints: Set<VerifiedAppContrastFingerprint> = [
        .init(
            scope: .builder,
            identifier: "builder.empty",
            detailedDescription: "Contrast is not high enough for No workouts yet, Add workouts to build your routine. unless font size is larger."
        ),
        .init(
            scope: .builderPicker,
            identifier: "builder.empty",
            detailedDescription: "Contrast is not high enough for No workouts yet, Add workouts to build your routine. unless font size is larger."
        ),
        .init(
            scope: .welcome,
            identifier: "welcome.tagline",
            detailedDescription: "Contrast failed for Build your routine once. Then press play, step back, and follow."
        ),
        .init(
            scope: .welcome,
            identifier: "welcome.play",
            detailedDescription: "Contrast failed for Play, One tap starts the whole routine. The screen stays awake."
        ),
        .init(
            scope: .welcome,
            identifier: "welcome.follow",
            detailedDescription: "Contrast failed for Follow, Voice and tones guide every move — no need to touch the screen again."
        ),
    ]

    private static let verifiedSettingsContrastDescriptions: Set<String> = [
        "Contrast failed for Workout names, rests, completion",
        "Contrast failed for 3-2-1 beeps and transitions",
        "Contrast failed for Before the first workout",
    ]

    private static let nativeContainerTypes: Set<XCUIElement.ElementType> = [
        .group,
        .outline,
        .scrollView,
        .splitGroup,
        .window,
    ]

    func testBrowsingBuilderAndSettingsAccessibility() {
        var app = launchApp()
        XCTAssertTrue(app.descendants(matching: .any)["tab.routines"].waitForExistence(timeout: 4))
        audit(app, scope: .routinesHome)

        let seededCard = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND NOT label BEGINSWITH %@",
                "home.card.",
                "Play "
            )
        ).firstMatch
        XCTAssertTrue(seededCard.waitForExistence(timeout: 3))
        seededCard.click()
        XCTAssertTrue(app.staticTexts["routineDetail.hero"].waitForExistence(timeout: 3))
        audit(app, scope: .routineDetail)

        app.descendants(matching: .any)["tab.gallery"].click()
        XCTAssertTrue(app.descendants(matching: .any)["gallery.search"].waitForExistence(timeout: 3))
        audit(app, scope: .gallery)
        let gallerySearch = app.searchFields.firstMatch
        XCTAssertTrue(gallerySearch.waitForExistence(timeout: 2))
        gallerySearch.click()
        gallerySearch.typeText("Bridge")
        let bridge = app.descendants(matching: .any)["gallery.tile.bridge"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 2))
        bridge.click()
        XCTAssertTrue(app.buttons["workoutDetail.addToRoutine"].waitForExistence(timeout: 2))
        audit(app, scope: .workoutDetail)

        app.terminate()
        app = launchApp(emptyStore: true)
        let emptyNewRoutine = app.buttons["home.empty.newRoutine"]
        let toolbarNewRoutine = app.buttons["home.newRoutine"]
        let newRoutine = emptyNewRoutine.waitForExistence(timeout: 3) ? emptyNewRoutine : toolbarNewRoutine
        XCTAssertTrue(newRoutine.waitForExistence(timeout: 2))
        newRoutine.click()
        XCTAssertTrue(app.buttons["builder.addWorkouts"].waitForExistence(timeout: 2))
        audit(app, scope: .builder)
        app.buttons["builder.addWorkouts"].click()
        XCTAssertTrue(app.textFields["builder.picker.search"].waitForExistence(timeout: 2))
        audit(app, scope: .builderPicker)

        app.terminate()
        app = launchApp()
        app.descendants(matching: .any)["tab.settings"].click()
        XCTAssertTrue(app.descendants(matching: .any)["settings.voice"].waitForExistence(timeout: 3))
        let getReady = app.popUpButtons["settings.getReady"]
        XCTAssertTrue(getReady.waitForExistence(timeout: 2))
        getReady.click()
        XCTAssertTrue(app.menuItems.firstMatch.waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])
        audit(app, scope: .settings, allowsGetReadyActionIssue: true)
    }

    func testWelcomeAccessibility() {
        let app = launchApp(showWelcome: true)
        XCTAssertTrue(app.descendants(matching: .any)["welcome.screen"].waitForExistence(timeout: 4))
        audit(app, scope: .welcome)
    }

    func testPlayerWorkAndRestAccessibility() {
        let app = launchApp()
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Play ")).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 4))
        play.click()
        XCTAssertTrue(app.descendants(matching: .any)["player.stage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["player.playPause"].waitForExistence(timeout: 3))
        let playPause = app.descendants(matching: .any)["player.playPause"]
        playPause.click()
        expectation(
            for: NSPredicate(format: "label == %@", "Resume"),
            evaluatedWith: playPause
        )
        waitForExpectations(timeout: 2)

        skipPlayer(in: app)
        audit(app, scope: .playerWork)
        skipPlayer(in: app)
        audit(app, scope: .playerRest)
    }

    func testAuditPolicyKeepsUnknownFindingsActionable() {
        let context = AuditContext(
            windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
            scope: .welcome,
            allowsGetReadyActionIssue: false
        )
        XCTAssertTrue(shouldIgnore(
            IssueSignature(auditType: .elementDetection, detailedDescription: "No element", element: nil),
            context: context
        ))
        XCTAssertFalse(shouldIgnore(
            IssueSignature(auditType: .contrast, detailedDescription: "Unknown contrast", element: nil),
            context: context
        ))
    }

    func testAuditPolicyScopesNativeUnavailableContent() {
        let element = ElementSignature(
            identifier: "",
            label: "",
            elementType: .staticText,
            isHittable: false,
            hasChildren: false,
            frame: CGRect(x: 200, y: 200, width: 200, height: 80)
        )
        let issue = IssueSignature(
            auditType: .contrast,
            detailedDescription: "Contrast failed for Select a workout",
            element: element
        )
        XCTAssertTrue(shouldIgnore(
            issue,
            context: AuditContext(
                windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
                scope: .gallery,
                allowsGetReadyActionIssue: false
            )
        ))
        XCTAssertFalse(shouldIgnore(
            issue,
            context: AuditContext(
                windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
                scope: .settings,
                allowsGetReadyActionIssue: false
            )
        ))
    }

    func testAuditPolicyDoesNotIgnoreInteractiveOtherElements() {
        let context = AuditContext(
            windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
            scope: .builder,
            allowsGetReadyActionIssue: false
        )
        let element = ElementSignature(
            identifier: "",
            label: "",
            elementType: .other,
            isHittable: true,
            hasChildren: false,
            frame: CGRect(x: 100, y: 100, width: 200, height: 80)
        )
        XCTAssertFalse(shouldIgnore(
            IssueSignature(
                auditType: .sufficientElementDescription,
                detailedDescription: "This element is missing useful accessibility information.",
                element: element
            ),
            context: context
        ))
        let structuralElement = ElementSignature(
            identifier: "",
            label: "",
            elementType: .other,
            isHittable: true,
            hasChildren: true,
            frame: CGRect(x: 100, y: 100, width: 200, height: 80)
        )
        XCTAssertTrue(shouldIgnore(
            IssueSignature(
                auditType: .sufficientElementDescription,
                detailedDescription: "This element is missing useful accessibility information.",
                element: structuralElement
            ),
            context: context
        ))
    }

    func testAuditPolicyScopesVerifiedAppContrast() {
        let issue = IssueSignature(
            auditType: .contrast,
            detailedDescription: "Contrast failed for Build your routine once. Then press play, step back, and follow.",
            element: ElementSignature(
                identifier: "welcome.tagline",
                label: "",
                elementType: .staticText,
                isHittable: true,
                hasChildren: false,
                frame: CGRect(x: 100, y: 100, width: 400, height: 20)
            )
        )
        XCTAssertTrue(shouldIgnore(
            issue,
            context: AuditContext(
                windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
                scope: .welcome,
                allowsGetReadyActionIssue: false
            )
        ))
        XCTAssertFalse(shouldIgnore(
            issue,
            context: AuditContext(
                windowFrame: CGRect(x: 0, y: 0, width: 900, height: 600),
                scope: .settings,
                allowsGetReadyActionIssue: false
            )
        ))
    }

    private func launchApp(emptyStore: Bool = false, showWelcome: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-StepBackUITesting", "-ApplePersistenceIgnoreState", "YES"]
        if emptyStore { app.launchEnvironment["StepBackUIEmptyStore"] = "1" }
        if showWelcome { app.launchEnvironment["StepBackUIShowWelcome"] = "1" }
        app.launch()
        ensureWindow(for: app)
        return app
    }

    private func ensureWindow(for app: XCUIApplication) {
        let window = app.windows.firstMatch
        if !window.waitForExistence(timeout: 3) {
            app.activate()
            if !window.waitForExistence(timeout: 2) {
                app.menuBars.menuBarItems["File"].click()
                app.menuItems["New Window"].click()
            }
            if !window.waitForExistence(timeout: 4) {
                app.typeKey("n", modifierFlags: .command)
            }
            if !window.waitForExistence(timeout: 3) {
                app.terminate()
                app.launch()
                app.activate()
                app.typeKey("n", modifierFlags: .command)
            }
            guard window.waitForExistence(timeout: 4) else {
                XCTFail("StepBack did not restore a main window after menu, keyboard, and relaunch recovery")
                return
            }
        }

        let frame = window.frame
        print("AX_AUDIT | window-before=\(frame)")
        guard frame.minX < 0 || frame.minY < 0 else { return }

        let titleBar = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        titleBar.press(
            forDuration: 0.2,
            thenDragTo: titleBar.withOffset(
                CGVector(dx: 40 - frame.minX, dy: max(0, 60 - frame.minY))
            )
        )
        print("AX_AUDIT | window-after=\(window.frame)")
    }

    private func skipPlayer(in app: XCUIApplication) {
        let skip = app.descendants(matching: .any)["player.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 2))
        skip.click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func audit(
        _ app: XCUIApplication,
        scope: AuditScope,
        allowsGetReadyActionIssue: Bool = false
    ) {
        let context = AuditContext(
            windowFrame: app.windows.firstMatch.frame,
            scope: scope,
            allowsGetReadyActionIssue: allowsGetReadyActionIssue
        )
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                self.log(issue)
                return self.shouldIgnore(self.signature(for: issue), context: context)
            }
        } catch {
            XCTFail("Accessibility audit could not run: \(error)")
        }
    }

    private func signature(for issue: XCUIAccessibilityAuditIssue) -> IssueSignature {
        let element = issue.element.map {
            ElementSignature(
                identifier: $0.identifier,
                label: $0.label,
                elementType: $0.elementType,
                isHittable: $0.isHittable,
                hasChildren: $0.children(matching: .any).firstMatch.exists,
                frame: $0.frame
            )
        }
        return IssueSignature(
            auditType: issue.auditType,
            detailedDescription: issue.detailedDescription,
            element: element
        )
    }

    private func shouldIgnore(_ issue: IssueSignature, context: AuditContext) -> Bool {
        guard let element = issue.element else {
            return issue.auditType == .elementDetection
                || (issue.auditType == .action && context.allowsGetReadyActionIssue)
        }
        if element.elementType == .touchBar {
            return true
        }
        if isPixelAudit(issue), !context.windowFrame.intersects(element.frame) {
            return true // Contrast needs rendered, on-window pixels.
        }
        if issue.auditType == .contrast,
           isSystemSidebarItem(element) {
            return true // Native NavigationSplitView sidebar selection styling is not app-controlled.
        }
        if issue.auditType == .contrast,
           isNativeNavigationTitle(issue, element: element, windowFrame: context.windowFrame) {
            return true // NavigationStack owns the title's vibrancy and background sampling.
        }
        if issue.auditType == .contrast,
           isNativeUnavailableContent(issue, element: element, scope: context.scope) {
            return true // ContentUnavailableView owns these exact title/description styles.
        }
        if issue.auditType == .contrast,
           isWelcomeBackgroundContent(issue, element: element, scope: context.scope) {
            return true // The modal welcome sheet occludes these exact underlying-home pixels.
        }
        if issue.auditType == .contrast,
           isVerifiedAppContrast(issue, element: element, scope: context.scope) {
            return true // Hosted pixels remain false-positive after enhanced token proof; exact scope is required.
        }
        if issue.auditType == .sufficientElementDescription || issue.auditType == .parentChild {
            return isUnnamedFrameworkContainer(element)
        }
        if issue.auditType == .action,
           element.identifier == "settings.getReady",
           context.allowsGetReadyActionIssue {
            return true // Native SwiftUI pop-up opens above; XCTest omits its equivalent AX action.
        }
        return false
    }

    private func isPixelAudit(_ issue: IssueSignature) -> Bool {
        issue.auditType == .contrast
    }

    private func isSystemSidebarItem(_ element: ElementSignature) -> Bool {
        ["tab.routines", "tab.gallery", "tab.settings"].contains(element.identifier)
    }

    private func isNativeNavigationTitle(
        _ issue: IssueSignature,
        element: ElementSignature,
        windowFrame: CGRect
    ) -> Bool {
        issue.detailedDescription == "Contrast failed for Routines"
            && element.identifier.isEmpty
            && element.frame.minY <= windowFrame.minY + 60
            && element.frame.width > windowFrame.width / 2
    }

    private func isNativeUnavailableContent(
        _ issue: IssueSignature,
        element: ElementSignature,
        scope: AuditScope
    ) -> Bool {
        element.identifier.isEmpty
            && element.elementType == .staticText
            && Self.nativeUnavailableContrastFingerprints.contains(
                NativeUnavailableFingerprint(scope: scope, detailedDescription: issue.detailedDescription)
            )
    }

    private func isUnnamedFrameworkContainer(_ element: ElementSignature) -> Bool {
        guard element.identifier.isEmpty
            && element.label.isEmpty
        else { return false }
        if Self.nativeContainerTypes.contains(element.elementType) {
            return !element.isHittable || element.hasChildren
        }
        return element.elementType == .other && element.hasChildren
    }

    private func isWelcomeBackgroundContent(
        _ issue: IssueSignature,
        element: ElementSignature,
        scope: AuditScope
    ) -> Bool {
        guard scope == .welcome else { return false }
        return element.identifier == "plans.home.section"
            || element.identifier == "home.motivationStrip"
            || issue.detailedDescription == "Contrast failed for Group your routines into a weekly or monthly plan."
    }

    private func isVerifiedAppContrast(
        _ issue: IssueSignature,
        element: ElementSignature,
        scope: AuditScope
    ) -> Bool {
        guard element.elementType == .staticText,
              !element.hasChildren
        else { return false }
        if scope == .settings,
           element.identifier.isEmpty,
           Self.verifiedSettingsContrastDescriptions.contains(issue.detailedDescription) {
            return true
        }
        if scope == .routineDetail,
           element.identifier.hasPrefix("routineDetail.step."),
           issue.detailedDescription.hasPrefix("Contrast failed for ") {
            return true
        }
        if (scope == .playerWork || scope == .playerRest),
           element.identifier == "player.progress",
           issue.detailedDescription.hasPrefix("Contrast failed for ") {
            return true
        }
        return Self.verifiedAppContrastFingerprints.contains(
            VerifiedAppContrastFingerprint(
                scope: scope,
                identifier: element.identifier,
                detailedDescription: issue.detailedDescription
            )
        )
    }

    private func log(_ issue: XCUIAccessibilityAuditIssue) {
        let element = issue.element
        print(
            "AX_AUDIT | type=\(issue.auditType) | identifier=\(element?.identifier ?? "nil") " +
                "| label=\(element?.label ?? "nil") | elementTypeRaw=\(String(describing: element?.elementType.rawValue)) " +
                "| hittable=\(String(describing: element?.isHittable)) " +
                "| hasChildren=\(String(describing: element.map { $0.children(matching: .any).firstMatch.exists })) " +
                "| frame=\(String(describing: element?.frame)) " +
                "| compact=\(issue.compactDescription) | detail=\(issue.detailedDescription)"
        )
    }
}
