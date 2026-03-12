import Foundation
import XCTest
@testable import AudioConverter

final class AudioConverterTests: XCTestCase {
    func testAppStateStartsWithDefaultFormat() {
        let state = AppState()

        XCTAssertEqual(state.outputFormat, "mp3")
        XCTAssertFalse(state.canStartConversion)
    }

    func testCanStartConversionIsTrueWhenFilesExistAndFormatIsNotBlank() {
        let state = AppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "flac"

        XCTAssertTrue(state.canStartConversion)
    }

    func testCanStartConversionIsFalseWhenFormatContainsOnlyWhitespace() {
        let state = AppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "   \n  "

        XCTAssertFalse(state.canStartConversion)
    }

    func testCanStartConversionIsFalseWhenStartupErrorExists() {
        let state = AppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "aac"
        state.startupError = "Missing ffmpeg"

        XCTAssertFalse(state.canStartConversion)
    }
}
