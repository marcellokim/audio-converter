import XCTest

final class AudioConverterUITests: XCTestCase {
    func testLaunchShowsApplicationTitle() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["AudioConverter"].exists)
    }

    func testStartConversionButtonIsDisabledOnLaunch() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertFalse(app.buttons["Start Conversion"].isEnabled)
    }

    func testSelectFilesButtonShowsPlaceholderStatusMessage() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Select Files"].tap()

        XCTAssertTrue(app.staticTexts["File selection adapter will be added in the next implementation cycle."].exists)
    }
}
