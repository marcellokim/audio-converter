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
        conversionScenario: String? = nil
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
