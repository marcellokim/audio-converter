import Foundation
import XCTest
@testable import AudioConverter

final class ConversionCoordinatorTests: XCTestCase {
    func testProcessReturnsSnapshotsInInputOrderForMixedResults() throws {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.results = [
            .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: "")),
            .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        ]

        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let coordinator = ConversionCoordinator(engine: engine, presenter: BatchStatusPresenter(), maximumConcurrentJobs: 2)
        let files = [
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/already-mp3.mp3")),
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/outro.aiff"))
        ]
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let snapshots = coordinator.process(
            files: files,
            format: format,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh")
        )

        XCTAssertEqual(snapshots.map(\.fileName), ["intro.wav", "already-mp3.mp3", "outro.aiff"])
        XCTAssertEqual(snapshots[0].state, .succeeded(outputURL: URL(fileURLWithPath: "/tmp/intro.mp3")))
        XCTAssertEqual(snapshots[0].detail, "Saved to intro.mp3.")
        XCTAssertEqual(snapshots[1].state, .skipped(reason: .sameFormat))
        XCTAssertEqual(snapshots[1].detail, "Input and output formats match, so the file was skipped.")
        XCTAssertEqual(snapshots[2].state, .succeeded(outputURL: URL(fileURLWithPath: "/tmp/outro.mp3")))
        XCTAssertEqual(snapshots[2].detail, "Saved to outro.mp3.")
        XCTAssertEqual(runner.invocations.count, 2)
    }

    func testProcessSurfacesFailureSnapshotWhenFFmpegReturnsNonZeroExit() throws {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        runner.results = [
            .success(FFmpegRunResult(terminationStatus: 1, standardOutput: "", standardError: "encoder failure"))
        ]

        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let coordinator = ConversionCoordinator(engine: engine, presenter: BatchStatusPresenter(), maximumConcurrentJobs: 1)
        let file = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/fail.wav"))
        let format = try XCTUnwrap(FormatRegistry.format(for: "flac"))

        let snapshots = coordinator.process(
            files: [file],
            format: format,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh")
        )

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].fileName, "fail.wav")
        XCTAssertEqual(snapshots[0].state, .failed(reason: .processFailed("encoder failure")))
        XCTAssertEqual(snapshots[0].detail, "encoder failure")
        XCTAssertEqual(fileManager.removedURLs, [URL(fileURLWithPath: "/tmp/temp-fail.flac")])
    }

    func testMakeSessionPublishesStableLiveUpdatesAndRunsSerially() throws {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let firstTask = MockFFmpegRunner.Task()
        let secondTask = MockFFmpegRunner.Task(
            result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        )
        runner.startResults = [.success(firstTask), .success(secondTask)]

        let engine = ConversionEngine(
            fileManager: fileManager,
            ffmpegRunner: runner,
            inputDurationProvider: FixedInputDurationProvider(durationSeconds: 10)
        )
        let coordinator = ConversionCoordinator(engine: engine, presenter: BatchStatusPresenter(), maximumConcurrentJobs: 2)
        let files = [
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/outro.aiff"))
        ]
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let completion = expectation(description: "session completed")
        let lock = NSLock()
        var updates: [[BatchStatusSnapshot]] = []
        var didEmitProgress = false
        var didReleaseFirstTask = false

        let session = coordinator.makeSession(
            files: files,
            format: format,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh"),
            onUpdate: { snapshots in
                lock.lock()
                updates.append(snapshots)
                lock.unlock()

                if !didEmitProgress, snapshots.map(\.state) == [.running, .queued] {
                    didEmitProgress = true
                    firstTask.emitProgress(FFmpegProgressEvent(outTimeSeconds: 5, progressState: "continue"))
                }

                if !didReleaseFirstTask,
                   snapshots.first?.progressPercentText == "50%" {
                    didReleaseFirstTask = true
                    XCTAssertEqual(runner.invocations.count, 1, "Second job should not start before the first finishes.")
                    firstTask.complete(
                        with: .success(
                            FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: "")
                        )
                    )
                }
            },
            onCompletion: { snapshots in
                lock.lock()
                updates.append(snapshots)
                lock.unlock()
                completion.fulfill()
            }
        )

        session.start()
        wait(for: [completion], timeout: 2)

        lock.lock()
        let capturedUpdates = updates
        lock.unlock()

        let firstOutputURL = URL(fileURLWithPath: "/tmp/intro.mp3")
        let secondOutputURL = URL(fileURLWithPath: "/tmp/outro.mp3")

        XCTAssertEqual(capturedUpdates.first?.map(\.state), [.queued, .queued])
        XCTAssertTrue(capturedUpdates.contains { $0.map(\.state) == [.running, .queued] })
        XCTAssertTrue(
            capturedUpdates.contains {
                $0.first?.progressPercentText == "50%" &&
                $0.first?.displayedDetail == "50% complete" &&
                $0.map(\.state) == [.running, .queued]
            }
        )
        XCTAssertTrue(capturedUpdates.contains { $0.map(\.state) == [.succeeded(outputURL: firstOutputURL), .queued] })
        XCTAssertTrue(capturedUpdates.contains { $0.map(\.state) == [.succeeded(outputURL: firstOutputURL), .running] })
        XCTAssertEqual(capturedUpdates.last?.map(\.state), [.succeeded(outputURL: firstOutputURL), .succeeded(outputURL: secondOutputURL)])
        XCTAssertEqual(runner.invocations.count, 2)

        let initialIDs = try XCTUnwrap(capturedUpdates.first?.map(\.id))
        XCTAssertTrue(capturedUpdates.allSatisfy { $0.count == 2 })
        XCTAssertTrue(capturedUpdates.allSatisfy { $0[0].id == initialIDs[0] && $0[1].id == initialIDs[1] })
    }

    func testMakeSessionCancelAllCancelsQueuedItemsImmediatelyAndStopsLaterStarts() throws {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let firstTask = MockFFmpegRunner.Task()
        firstTask.onCancel = {
            firstTask.complete(
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
        runner.startResults = [
            .success(firstTask),
            .success(MockFFmpegRunner.Task(result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))))
        ]

        let engine = ConversionEngine(fileManager: fileManager, ffmpegRunner: runner)
        let coordinator = ConversionCoordinator(engine: engine, presenter: BatchStatusPresenter(), maximumConcurrentJobs: 2)
        let files = [
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/outro.aiff"))
        ]
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let completion = expectation(description: "session completed after cancellation")
        let lock = NSLock()
        var updates: [[BatchStatusSnapshot]] = []
        var session: ConversionCoordinatorSession?
        var didCancel = false

        session = coordinator.makeSession(
            files: files,
            format: format,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh"),
            onUpdate: { snapshots in
                lock.lock()
                updates.append(snapshots)
                lock.unlock()

                if !didCancel, snapshots.map(\.state) == [.running, .queued] {
                    didCancel = true
                    session?.cancelAll()
                }
            },
            onCompletion: { snapshots in
                lock.lock()
                updates.append(snapshots)
                lock.unlock()
                completion.fulfill()
            }
        )

        session?.start()
        wait(for: [completion], timeout: 2)

        lock.lock()
        let capturedUpdates = updates
        lock.unlock()

        XCTAssertTrue(capturedUpdates.contains { $0.map(\.state) == [.running, .cancelled] })
        XCTAssertEqual(capturedUpdates.last?.map(\.state), [.cancelled, .cancelled])
        XCTAssertEqual(runner.invocations.count, 1, "Queued work should not start after batch cancellation.")
        XCTAssertEqual(firstTask.cancelCount, 1)
        XCTAssertEqual(fileManager.removedURLs, [URL(fileURLWithPath: "/tmp/temp-intro.mp3")])

        let initialIDs = try XCTUnwrap(capturedUpdates.first?.map(\.id))
        XCTAssertTrue(capturedUpdates.allSatisfy { $0[0].id == initialIDs[0] && $0[1].id == initialIDs[1] })
    }
}

private struct FixedInputDurationProvider: InputDurationProviding {
    let durationSeconds: Double?

    func durationSeconds(for url: URL) -> Double? {
        durationSeconds
    }
}
