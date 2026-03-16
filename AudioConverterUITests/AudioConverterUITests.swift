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

        XCTAssertFalse(app.buttons["Start Conversion"].isEnabled)
        XCTAssertFalse(app.buttons["Cancel Batch"].exists)
    }

    func testSelectFilesButtonBecomesEnabledAfterStartupCheck() {
        let app = makeApp()
        app.launch()

        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 5))

        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: selectFilesButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    func testRetryStartupCheckButtonAppearsWhenStartupFails() {
        let app = makeApp(startupScenario: "always-fail")
        app.launch()

        let retryButton = app.buttons["Retry Startup Check"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Select Files"].isEnabled)
    }

    func testRetryStartupCheckCanRecoverToEnabledFileSelection() {
        let app = makeApp(startupScenario: "fail-then-success")
        app.launch()

        let retryButton = app.buttons["Retry Startup Check"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        retryButton.tap()

        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 5))

        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: selectFilesButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertFalse(retryButton.exists)
    }

    func testSelectFilesScenarioStagesChosenFilesAndEnablesConversion() {
        let app = makeApp(fileSelectionScenario: "multiple")
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-test-source-2.aiff"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Conversion"].isEnabled)
    }

    func testSelectFilesCancelScenarioShowsCancellationMessage() {
        let app = makeApp(fileSelectionScenario: "cancel")
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["File selection cancelled."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start Conversion"].isEnabled)
    }

    func testSelectFilesCancelAfterSelectionKeepsExistingFilesLoaded() {
        let app = makeApp(fileSelectionScenario: "multiple,cancel")
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Conversion"].isEnabled)

        selectFilesButton.tap()

        XCTAssertTrue(app.staticTexts["File selection cancelled. Keeping 2 loaded file(s)."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ui-test-source-1.wav"].exists)
        XCTAssertTrue(app.staticTexts["ui-test-source-2.aiff"].exists)
        XCTAssertTrue(app.buttons["Start Conversion"].isEnabled)
    }

    func testConversionScenarioRunsFromSelectionThroughCompletion() {
        let app = makeApp(
            fileSelectionScenario: "multiple",
            conversionScenario: "complete-success"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        let startConversionButton = app.buttons["start-conversion"]
        XCTAssertTrue(startConversionButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startConversionButton.isEnabled)

        startConversionButton.tap()

        XCTAssertTrue(app.staticTexts["Finished conversion to MP3: 2 converted."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Complete 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved to ui-test-source-1.mp3."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Saved to ui-test-source-2.mp3."].waitForExistence(timeout: 5))
    }

    func testConversionScenarioCanCancelAnInFlightBatch() {
        let app = makeApp(
            fileSelectionScenario: "multiple",
            conversionScenario: "cancel-after-start"
        )
        app.launch()

        let selectFilesButton = waitForEnabledSelectFilesButton(in: app)
        selectFilesButton.tap()

        let startConversionButton = app.buttons["start-conversion"]
        XCTAssertTrue(startConversionButton.waitForExistence(timeout: 5))
        startConversionButton.tap()

        let cancelBatchButton = app.buttons["cancel-conversion"]
        XCTAssertTrue(cancelBatchButton.waitForExistence(timeout: 5))

        cancelBatchButton.tap()

        XCTAssertTrue(app.staticTexts["Finished conversion to MP3: 2 cancelled."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cancelled 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cancelled before completion."].waitForExistence(timeout: 5))
    }

    private func makeApp(
        startupScenario: String? = nil,
        fileSelectionScenario: String? = nil,
        conversionScenario: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()

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
        let selectFilesButton = app.buttons["Select Files"]
        XCTAssertTrue(selectFilesButton.waitForExistence(timeout: 5))

        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: enabledPredicate, object: selectFilesButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)

        return selectFilesButton
    }
}
