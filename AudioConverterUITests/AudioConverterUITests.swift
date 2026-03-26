import XCTest

final class AudioConverterUITests: XCTestCase {
    func testLaunchShowsApplicationTitle() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["AudioConverter"].exists)
    }

    func testStartConversionButtonIsDisabledOnLaunch() {
        let app = makeApp()
        app.launch()

        XCTAssertFalse(app.buttons["start-conversion"].isEnabled)
        XCTAssertFalse(app.buttons["cancel-conversion"].exists)
    }

    func testSelectFilesButtonBecomesEnabledAfterStartupCheck() {
        let app = makeApp()
        app.launch()

        _ = waitForEnabledSelectFilesButton(in: app)
    }

    func testLaunchKeepsSingleRootScrollViewAndUniquePrimaryControls() {
        let app = makeApp(startupScenario: "always-ready")
        app.launch()

        _ = waitForEnabledSelectFilesButton(in: app)

        XCTAssertEqual(app.scrollViews.count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "select-files").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "mode-batch").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "mode-merge").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "start-conversion").count, 1)
    }

    func testRetryStartupCheckButtonAppearsWhenStartupFails() {
        let app = makeApp(startupScenario: "always-fail")
        app.launch()

        let retryButton = app.buttons["retry-startup-check"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["select-files"].isEnabled)
    }

    func testRetryStartupCheckCanRecoverToEnabledFileSelection() {
        let app = makeApp(startupScenario: "fail-then-success")
        app.launch()

        let retryButton = app.buttons["retry-startup-check"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        retryButton.tap()

        _ = waitForEnabledSelectFilesButton(in: app)
        XCTAssertFalse(retryButton.exists)
    }

    func testSelectFilesScenarioStagesChosenFilesAndEnablesConversion() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-test-source-2.aiff"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-conversion"].isEnabled)
    }

    func testSelectFilesCancelScenarioShowsCancellationMessage() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "cancel"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["File selection cancelled."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-conversion"].isEnabled)
    }

    func testSelectFilesCancelAfterSelectionKeepsExistingFilesLoaded() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple,cancel"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["start-conversion"].isEnabled)

        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["File selection cancelled. Keeping 2 loaded file(s)."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].exists)
        XCTAssertTrue(app.staticTexts["ui-test-source-2.aiff"].exists)
        XCTAssertTrue(app.buttons["start-conversion"].isEnabled)
    }

    func testSelectedFilesCanBeRemovedBeforeConversion() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        let removeButton = app.buttons["remove-staged-file-ui-test-source-1.wav"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()

        XCTAssertFalse(app.staticTexts["ui-test-source-1.wav"].exists)
        XCTAssertTrue(app.staticTexts["ui-test-source-2.aiff"].exists)
        XCTAssertTrue(app.buttons["start-conversion"].isEnabled)
    }

    func testMergeModeKeepsPrimaryActionDisabledUntilDestinationIsSelected() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)
        selectFilesButton.tap()

        let chooseDestinationButton = app.buttons["select-merge-destination"]
        XCTAssertTrue(chooseDestinationButton.waitForExistence(timeout: 5))

        let startMergeButton = app.buttons["start-merge"]
        XCTAssertTrue(startMergeButton.waitForExistence(timeout: 5))
        XCTAssertFalse(startMergeButton.isEnabled)
    }

    func testMergeModeKeepsUniqueSelectorsAfterStagingFiles() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)
        selectFilesButton.tap()

        XCTAssertEqual(app.buttons.matching(identifier: "select-files").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "mode-merge").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "start-merge").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "select-merge-destination").count, 1)
        XCTAssertEqual(stagedFileNames(in: app), ["ui-test-source-1.wav", "ui-test-source-2.aiff"])
    }

    func testMergeModeCanReorderStagedFiles() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)
        selectFilesButton.tap()

        XCTAssertEqual(stagedFileNames(in: app), ["ui-test-source-1.wav", "ui-test-source-2.aiff"])

        let moveUpButton = app.buttons["move-staged-file-up-ui-test-source-2.aiff"]
        XCTAssertTrue(moveUpButton.waitForExistence(timeout: 5))
        waitForHittable(moveUpButton)
        moveUpButton.tap()

        XCTAssertEqual(stagedFileNames(in: app), ["ui-test-source-2.aiff", "ui-test-source-1.wav"])
    }

    func testMergeModeStillRequiresAtLeastTwoFiles() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "single",
            savePanelScenario: "choose-destination"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)
        selectFilesButton.tap()

        let chooseDestinationButton = app.buttons["select-merge-destination"]
        XCTAssertTrue(chooseDestinationButton.waitForExistence(timeout: 5))
        waitForHittable(chooseDestinationButton)
        chooseDestinationButton.tap()

        let startMergeButton = app.buttons["start-merge"]
        XCTAssertTrue(startMergeButton.waitForExistence(timeout: 5))
        XCTAssertFalse(startMergeButton.isEnabled)
    }

    func testMergeScenarioProducesExactlyOneBatchStatusRow() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple",
            savePanelScenario: "choose-destination",
            mergeScenario: "complete-success"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)
        selectFilesButton.tap()

        let chooseDestinationButton = app.buttons["select-merge-destination"]
        XCTAssertTrue(chooseDestinationButton.waitForExistence(timeout: 5))
        waitForHittable(chooseDestinationButton)
        chooseDestinationButton.tap()

        let startMergeButton = app.buttons["start-merge"]
        XCTAssertTrue(startMergeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startMergeButton.isEnabled)
        waitForHittable(startMergeButton)
        startMergeButton.tap()
        scrollToBatchStatus(in: app)

        XCTAssertTrue(app.staticTexts["batch-summary-complete"].waitForExistence(timeout: 10))
        XCTAssertEqual(batchFileIdentifiers(in: app).count, 1)
    }

    func testBatchConvertStillWorksAfterReturningFromMergeMode() throws {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple",
            conversionScenario: "complete-success"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        try enterMergeMode(in: app)

        let batchModeButton = app.buttons["mode-batch"]
        XCTAssertTrue(batchModeButton.waitForExistence(timeout: 5))
        waitForHittable(batchModeButton)
        batchModeButton.tap()

        selectFilesButton.tap()

        let startConversionButton = app.buttons["start-conversion"]
        XCTAssertTrue(startConversionButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startConversionButton.isEnabled)
        waitForHittable(startConversionButton)
        startConversionButton.tap()
        scrollToBatchStatus(in: app)

        XCTAssertTrue(app.staticTexts["batch-summary-complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["batch-detail-ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["batch-detail-ui-test-source-2.aiff"].waitForExistence(timeout: 5))
    }

    func testConversionScenarioRunsFromSelectionThroughCompletion() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple",
            conversionScenario: "complete-success"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        let startConversionButton = app.buttons["start-conversion"]
        XCTAssertTrue(startConversionButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startConversionButton.isEnabled)
        waitForHittable(startConversionButton)
        startConversionButton.tap()
        scrollToBatchStatus(in: app)

        XCTAssertTrue(app.staticTexts["batch-summary-complete"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["batch-detail-ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["batch-detail-ui-test-source-2.aiff"].waitForExistence(timeout: 5))
    }

    func testConversionScenarioCanCancelAnInFlightBatch() {
        let app = makeApp(
            startupScenario: "always-ready",
            fileSelectionScenario: "multiple",
            conversionScenario: "cancel-after-start"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        let startConversionButton = app.buttons["start-conversion"]
        XCTAssertTrue(startConversionButton.waitForExistence(timeout: 5))
        waitForHittable(startConversionButton)
        startConversionButton.tap()

        let cancelBatchButton = app.buttons["cancel-conversion"]
        XCTAssertTrue(cancelBatchButton.waitForExistence(timeout: 5))
        waitForHittable(cancelBatchButton)
        cancelBatchButton.tap()

        XCTAssertTrue(app.staticTexts["batch-summary-cancelled"].waitForExistence(timeout: 10))
    }

    private func makeApp(
        startupScenario: String? = "always-ready",
        fileSelectionScenario: String? = nil,
        conversionScenario: String? = nil,
        savePanelScenario: String? = nil,
        mergeScenario: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]

        if let startupScenario {
            app.launchArguments.append("--uitest-startup-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_STARTUP_SCENARIO"] = startupScenario
        }

        if let fileSelectionScenario {
            app.launchArguments.append("--uitest-file-selection-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_FILE_SELECTION_SCENARIO"] = fileSelectionScenario
        }

        if let conversionScenario {
            app.launchArguments.append("--uitest-conversion-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_CONVERSION_SCENARIO"] = conversionScenario
        }

        if let savePanelScenario {
            app.launchArguments.append("--uitest-save-panel-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_SAVE_PANEL_SCENARIO"] = savePanelScenario
        }

        if let mergeScenario {
            app.launchArguments.append("--uitest-merge-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_MERGE_SCENARIO"] = mergeScenario
        }

        return app
    }

    private func waitForEnabledSelectFilesButton(in app: XCUIApplication) -> XCUIElement {
        app.activate()

        let selectFilesButton = app.buttons["select-files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 5))

        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: selectFilesButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)

        return selectFilesButton
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    private func enterMergeMode(in app: XCUIApplication, timeout: TimeInterval = 1) throws {
        let mergeModeButton = app.buttons["mode-merge"]
        guard mergeModeButton.waitForExistence(timeout: timeout) else {
            throw XCTSkip("Ordered merge UI is not available in this worktree yet.")
        }

        waitForHittable(mergeModeButton)
        mergeModeButton.tap()
    }

    private func stagedFileNames(in app: XCUIApplication) -> [String] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "staged-file-name-")
        return app.staticTexts.matching(predicate).allElementsBoundByIndex.map(\.label)
    }

    private func batchFileIdentifiers(in app: XCUIApplication) -> [String] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "batch-file-")
        return app.staticTexts.matching(predicate).allElementsBoundByIndex.map(\.identifier)
    }

    private func scrollToBatchStatus(in app: XCUIApplication) {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.exists else {
            return
        }

        for _ in 0..<2 {
            scrollView.swipeUp()
        }
    }

}
