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

    private func makeApp(startupScenario: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()

        if let startupScenario {
            app.launchArguments.append("--uitest-startup-scenario")
            app.launchEnvironment["AUDIOCONVERTER_UI_TEST_STARTUP_SCENARIO"] = startupScenario
        }

        return app
    }
}
