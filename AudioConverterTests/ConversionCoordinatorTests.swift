import Foundation
import XCTest
@testable import AudioConverter

final class ConversionCoordinatorTests: XCTestCase {
    func testProcessReturnsSnapshotsInInputOrderForMixedResults() {
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
}
