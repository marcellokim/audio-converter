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
        let state = makeReadyAppState()
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

    func testCanStartConversionRecoversAfterStartupErrorClears() {
        var resolution: AppState.FFmpegResolution = .failure("Missing ffmpeg")
        let state = AppState(
            resolveFFmpegURL: { resolution },
            validateStartupCapabilities: { _ in .ready }
        )
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "aac"

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Missing ffmpeg") = $0 {
                return true
            }

            return false
        }

        XCTAssertFalse(state.canStartConversion)

        resolution = .ready(URL(fileURLWithPath: "/bin/sh"))
        state.performStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }

        XCTAssertTrue(state.canStartConversion)
    }

    func testCanRetryStartupChecksIsOnlyAvailableAfterStartupFailure() {
        var validationResults: [StartupState] = [.startupError("Missing ffmpeg"), .ready]
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in validationResults.removeFirst() }
        )

        XCTAssertFalse(state.canRetryStartupChecks)

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Missing ffmpeg") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)

        state.retryStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }

        XCTAssertFalse(state.canRetryStartupChecks)
        XCTAssertNil(state.startupError)
    }

    func testRetryStartupChecksKeepsStartupBlockedWhenFailurePersists() {
        var attempts = 0
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in
                attempts += 1
                return .startupError("Startup failure attempt \(attempts)")
            }
        )

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Startup failure attempt 1") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)
        XCTAssertFalse(state.canStartConversion)

        state.retryStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Startup failure attempt 2") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)
        XCTAssertFalse(state.canOpenFiles)
        XCTAssertFalse(state.canStartConversion)
    }

    private func makeReadyAppState() -> AppState {
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in .ready }
        )
        state.performStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }
        return state
    }

    private func waitForStartupState(
        of state: AppState,
        timeout: TimeInterval = 1,
        matches predicate: (StartupState) -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while !predicate(state.startupState) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertTrue(predicate(state.startupState), "Timed out waiting for startup state, got \(state.startupState)")
    }
}
