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

    func testStartConversionConsumesLiveSessionUpdatesBeforeCompletion() {
        let session = ControlledConversionSession()
        let state = makeReadyAppState(session: session)
        let snapshotID = UUID()
        let queued = BatchStatusSnapshot(id: snapshotID, fileName: "example.wav", state: .queued)
        let running = queued.updating(state: .running)
        let completed = queued.updating(state: .succeeded(outputURL: URL(fileURLWithPath: "/tmp/example.mp3")))

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "mp3"
        session.onStart = {
            session.emitUpdate([queued])
            session.emitUpdate([running])
        }

        state.startConversion()

        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertTrue(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertTrue(state.canCancelConversion)
        XCTAssertEqual(state.batchSnapshots, [running])

        session.emitCompletion([completed])

        XCTAssertFalse(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertFalse(state.canCancelConversion)
        XCTAssertEqual(state.batchSnapshots, [completed])
        XCTAssertEqual(state.statusMessage, "Finished conversion to MP3: 1 converted.")
    }

    func testCancelConversionRequestsSessionCancellationAndTracksCancelledCompletion() {
        let session = ControlledConversionSession()
        let state = makeReadyAppState(session: session)
        let snapshotID = UUID()
        let queued = BatchStatusSnapshot(id: snapshotID, fileName: "example.wav", state: .queued)
        let cancelled = queued.updating(state: .cancelled)

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "mp3"
        session.onStart = {
            session.emitUpdate([queued])
        }

        state.startConversion()
        state.cancelConversion()

        XCTAssertEqual(session.cancelCallCount, 1)
        XCTAssertTrue(state.isConverting)
        XCTAssertTrue(state.isCancelling)
        XCTAssertFalse(state.canCancelConversion)
        XCTAssertEqual(state.statusMessage, "Cancelling current batch…")

        session.emitUpdate([cancelled])
        session.emitCompletion([cancelled])

        XCTAssertFalse(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertEqual(state.batchSnapshots, [cancelled])
        XCTAssertEqual(state.statusMessage, "Finished conversion to MP3: 1 cancelled.")
    }

    private func makeReadyAppState(session: ControlledConversionSession? = nil) -> AppState {
        let controlledSession = session ?? ControlledConversionSession()
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in .ready },
            makeConversionSession: { _, _, _, onUpdate, onCompletion in
                controlledSession.onUpdate = onUpdate
                controlledSession.onCompletion = onCompletion
                return controlledSession
            }
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

private final class ControlledConversionSession: BatchConversionSessioning {
    var onStart: (() -> Void)?
    var onUpdate: (([BatchStatusSnapshot]) -> Void)?
    var onCompletion: (([BatchStatusSnapshot]) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    func start() {
        startCallCount += 1
        onStart?()
    }

    func cancelAll() {
        cancelCallCount += 1
    }

    func emitUpdate(_ snapshots: [BatchStatusSnapshot]) {
        onUpdate?(snapshots)
    }

    func emitCompletion(_ snapshots: [BatchStatusSnapshot]) {
        onCompletion?(snapshots)
    }
}
