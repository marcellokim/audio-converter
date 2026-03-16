import Foundation
import XCTest
@testable import AudioConverter

final class ConversionEngineTests: XCTestCase {
    func testMakeJobSkipsSameFormat() throws {
        let engine = ConversionEngine(fileManager: MockFileManager(), ffmpegRunner: MockFFmpegRunner())
        let file = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/track.mp3"))
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let result = engine.makeJob(for: file, format: format)

        guard case let .failure(state) = result else {
            return XCTFail("Expected failure result")
        }
        XCTAssertEqual(state, .skipped(reason: .sameFormat))
    }

    func testMakeJobSkipsWhenDestinationAlreadyExists() throws {
        let file = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/track.wav"))
        let format = try XCTUnwrap(FormatRegistry.format(for: "flac"))
        let destinationURL = URL(fileURLWithPath: "/tmp/track.flac")
        let fileManager = MockFileManager()
        fileManager.existingURLs.insert(destinationURL)
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: MockFFmpegRunner())

        let result = engine.makeJob(for: file, format: format)

        guard case let .failure(state) = result else {
            return XCTFail("Expected failure result")
        }
        XCTAssertEqual(state, .skipped(reason: .conflictExistingOutput))
    }

    func testRunMovesTemporaryOutputOnSuccess() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.results = [Result.success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "mp3", temporaryName: ".track.partial.mp3")

        let result = engine.run(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        XCTAssertEqual(result, .succeeded(outputURL: job.outputURL))
        XCTAssertEqual(fileManager.movedPairs.count, 1)
        XCTAssertEqual(fileManager.movedPairs.first?.source, job.temporaryOutputURL)
        XCTAssertEqual(fileManager.movedPairs.first?.destination, job.outputURL)
        XCTAssertTrue(fileManager.removedURLs.isEmpty)
        XCTAssertEqual(
            Array(runner.invocations.first?.arguments.prefix(8) ?? []),
            ["-hide_banner", "-loglevel", "error", "-nostdin", "-nostats", "-progress", "pipe:1", "-n"]
        )
    }

    func testRunCleansUpTemporaryOutputOnNonZeroExit() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.results = [Result.success(FFmpegRunResult(terminationStatus: 1, standardOutput: "", standardError: "encoder blew up"))]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "mp3", temporaryName: ".track.partial.mp3")

        let result = engine.run(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        XCTAssertEqual(result, .failed(reason: .processFailed("encoder blew up")))
        XCTAssertEqual(fileManager.removedURLs, [job.temporaryOutputURL])
    }

    func testRunMapsFileExistsErrorToSkippedConflict() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.results = [Result.success(FFmpegRunResult(terminationStatus: 1, standardOutput: "", standardError: "File exists"))]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "flac", temporaryName: ".track.partial.flac")

        let result = engine.run(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        XCTAssertEqual(result, .skipped(reason: .conflictExistingOutput))
        XCTAssertEqual(fileManager.removedURLs, [job.temporaryOutputURL])
    }

    func testRunMapsAtomicMoveConflictToSkippedConflict() {
        let fileManager = MockFileManager()
        fileManager.moveError = CocoaError(.fileWriteFileExists)
        let runner = MockFFmpegRunner()
        runner.results = [Result.success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "aac", temporaryName: ".track.partial.aac")

        let result = engine.run(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        XCTAssertEqual(result, .skipped(reason: .conflictExistingOutput))
        XCTAssertEqual(fileManager.removedURLs, [job.temporaryOutputURL])
    }

    func testStartHandleCancelMapsCancelledTaskToCancelledAndCleansUpTemporaryOutput() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let task = MockFFmpegRunner.Task()
        task.onCancel = {
            task.complete(
                with: .success(
                    FFmpegRunResult(
                        terminationStatus: 15,
                        standardOutput: "",
                        standardError: "terminated",
                        wasCancelled: true
                    )
                )
            )
        }
        runner.startResults = [.success(task)]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "m4a", temporaryName: ".track.partial.m4a")

        let startResult = engine.start(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        guard case let .success(handle) = startResult else {
            return XCTFail("Expected successful execution handle")
        }

        handle.cancel()

        XCTAssertEqual(task.cancelCount, 1)
        XCTAssertEqual(handle.waitForCompletion(), .cancelled)
        XCTAssertEqual(fileManager.removedURLs, [job.temporaryOutputURL])
    }

    func testRunMapsLaunchFailuresAndCleansUpTemporaryOutput() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.startResults = [.failure(MockFFmpegRunner.RunnerError.launchFailed)]
        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let job = makeJob(outputExtension: "ogg", temporaryName: ".track.partial.ogg")

        let result = engine.run(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        guard case let .failed(reason) = result else {
            return XCTFail("Expected failed state")
        }
        guard case let .processLaunchFailed(message) = reason else {
            return XCTFail("Expected processLaunchFailed")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(fileManager.removedURLs, [job.temporaryOutputURL])
    }

    func testStartPublishesNormalizedProgressWhenDurationIsKnown() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let durationProvider = StubInputDurationProvider(durationSeconds: 20)
        let task = MockFFmpegRunner.Task(
            result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        )
        runner.startResults = [.success(task)]
        let engine = ConversionEngine(
            fileManager: fileManager,
            ffmpegRunner: runner,
            inputDurationProvider: durationProvider
        )
        let job = makeJob(outputExtension: "mp3", temporaryName: ".track.partial.mp3")
        var captured: [ConversionProgress] = []

        let result = engine.start(
            job: job,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh"),
            onProgress: { captured.append($0) }
        )

        guard case let .success(handle) = result else {
            return XCTFail("Expected successful execution handle")
        }

        task.emitProgress(FFmpegProgressEvent(outTimeSeconds: 5, progressState: "continue"))
        _ = handle.waitForCompletion()

        XCTAssertEqual(
            captured,
            [ConversionProgress(fractionCompleted: 0.25, isIndeterminate: false, progressDetail: "25% complete")]
        )
    }

    func testStartPublishesIndeterminateProgressWhenDurationIsUnavailable() {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let durationProvider = StubInputDurationProvider(durationSeconds: nil)
        let task = MockFFmpegRunner.Task(
            result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        )
        runner.startResults = [.success(task)]
        let engine = ConversionEngine(
            fileManager: fileManager,
            ffmpegRunner: runner,
            inputDurationProvider: durationProvider
        )
        let job = makeJob(outputExtension: "mp3", temporaryName: ".track.partial.mp3")
        var captured: [ConversionProgress] = []

        let result = engine.start(
            job: job,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh"),
            onProgress: { captured.append($0) }
        )

        guard case let .success(handle) = result else {
            return XCTFail("Expected successful execution handle")
        }

        task.emitProgress(FFmpegProgressEvent(outTimeSeconds: 3.5, progressState: "continue"))
        _ = handle.waitForCompletion()

        XCTAssertEqual(
            captured,
            [ConversionProgress(fractionCompleted: nil, isIndeterminate: true, progressDetail: "Rendered 3.5s so far.")]
        )
    }

    private func makeJob(outputExtension: String, temporaryName: String) -> ConversionJob {
        let inputURL = URL(fileURLWithPath: "/tmp/track.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/track.\(outputExtension)")
        let temporaryOutputURL = URL(fileURLWithPath: "/tmp/\(temporaryName)")
        return ConversionJob(
            inputFile: SelectedAudioFile(url: inputURL),
            outputFormat: SupportedFormat(
                id: outputExtension,
                displayName: outputExtension.uppercased(),
                outputExtension: outputExtension,
                requiredEncoderKey: outputExtension,
                requiredMuxerKey: outputExtension,
                ffmpegArgs: ["-vn", "-c:a", outputExtension]
            ),
            outputURL: outputURL,
            temporaryOutputURL: temporaryOutputURL
        )
    }
}

private struct StubInputDurationProvider: InputDurationProviding {
    let durationSeconds: Double?

    func durationSeconds(for url: URL) -> Double? {
        durationSeconds
    }
}
