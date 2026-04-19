import Foundation
import XCTest
@testable import AudioConverter

final class MergeExportEngineTests: XCTestCase {
    func testMakeJobRequiresAtLeastTwoFiles() throws {
        let engine = MergeExportEngine(
            fileManager: MockFileManager(),
            ffmpegRunner: MockFFmpegRunner(),
            inputDurationProvider: ConstantDurationProvider(durationSeconds: 5)
        )
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let result = engine.makeJob(
            for: [SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav"))],
            format: format,
            destinationURL: URL(fileURLWithPath: "/tmp/merged.mp3")
        )

        guard case let .failure(state) = result else {
            return XCTFail("Expected validation failure")
        }
        XCTAssertEqual(
            state,
            ConversionItemState.failed(reason: .validation("Select at least two source audio files before merging."))
        )
    }

    func testMakeJobAllowsExistingDestinationForOverwrite() throws {
        let fileManager = MockFileManager()
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let destinationURL = URL(fileURLWithPath: "/tmp/merged.mp3")
        fileManager.existingURLs.insert(destinationURL)
        let engine = MergeExportEngine(
            fileManager: fileManager,
            ffmpegRunner: MockFFmpegRunner(),
            inputDurationProvider: ConstantDurationProvider(durationSeconds: 5)
        )

        let result = engine.makeJob(
            for: [
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/outro.wav"))
            ],
            format: format,
            destinationURL: destinationURL
        )

        guard case let .success(job) = result else {
            return XCTFail("Expected merge job even when destination already exists")
        }
        XCTAssertEqual(job.outputURL, destinationURL)
    }

    func testMakeJobSumsInputDurationsWhenKnown() throws {
        let fileManager = MockFileManager()
        let durationProvider = SequenceDurationProvider(values: [3, 7])
        let engine = MergeExportEngine(
            fileManager: fileManager,
            ffmpegRunner: MockFFmpegRunner(),
            inputDurationProvider: durationProvider
        )
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let destinationURL = URL(fileURLWithPath: "/tmp/merged.mp3")

        let result = engine.makeJob(
            for: [
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/verse.wav"))
            ],
            format: format,
            destinationURL: destinationURL
        )

        guard case let .success(job) = result else {
            return XCTFail("Expected merge job")
        }
        XCTAssertEqual(job.totalDurationSeconds, 10)
        XCTAssertEqual(job.temporaryOutputURL, fileManager.makeTemporaryOutputURL(for: destinationURL))
    }

    func testStartUsesOrderedMergeArgumentsAndMovesOutputOnSuccess() throws {
        let fileManager = MockFileManager()
        let runner = MockFFmpegRunner()
        let task = MockFFmpegRunner.Task(
            result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        )
        runner.startResults = [.success(task)]
        let engine = MergeExportEngine(
            fileManager: fileManager,
            ffmpegRunner: runner,
            inputDurationProvider: ConstantDurationProvider(durationSeconds: 12)
        )
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let destinationURL = URL(fileURLWithPath: "/tmp/merged.mp3")
        let temporaryOutputURL = URL(fileURLWithPath: "/tmp/merged.partial.mp3")
        fileManager.temporaryOutputURLs[destinationURL] = temporaryOutputURL
        let job = try XCTUnwrap(
            try? engine.makeJob(
                for: [
                    SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav")),
                    SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/verse.wav"))
                ],
                format: format,
                destinationURL: destinationURL
            ).get()
        )
        var progressEvents: [ConversionProgress] = []

        let result = engine.start(
            job: job,
            ffmpegURL: URL(fileURLWithPath: "/bin/sh"),
            onProgress: { progressEvents.append($0) }
        )

        guard case let .success(handle) = result else {
            return XCTFail("Expected successful merge handle")
        }

        task.emitProgress(FFmpegProgressEvent(outTimeSeconds: 3, progressState: "continue"))
        XCTAssertEqual(
            progressEvents,
            [ConversionProgress(fractionCompleted: 0.125, isIndeterminate: false, progressDetail: "13% merged")]
        )

        XCTAssertEqual(
            runner.invocations.first?.arguments.prefix(12),
            ["-hide_banner", "-loglevel", "error", "-nostdin", "-nostats", "-progress", "pipe:1", "-n", "-i", "/tmp/intro.wav", "-i", "/tmp/verse.wav"]
        )
        XCTAssertEqual(handle.waitForCompletion(), ConversionItemState.succeeded(outputURL: destinationURL))
        XCTAssertEqual(fileManager.movedPairs.first?.source, temporaryOutputURL)
        XCTAssertEqual(fileManager.movedPairs.first?.destination, destinationURL)
    }

    func testStartReplacesExistingDestinationWhenMergeSucceeds() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let runner = MockFFmpegRunner()
        let task = MockFFmpegRunner.Task(
            result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: ""))
        )
        runner.startResults = [.success(task)]
        let engine = MergeExportEngine(
            fileManager: DefaultFileManagerAdapter(),
            ffmpegRunner: runner,
            inputDurationProvider: ConstantDurationProvider(durationSeconds: 4)
        )
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let destinationURL = tempDirectory.appendingPathComponent("merged.mp3")
        try Data("existing".utf8).write(to: destinationURL)

        let job = try XCTUnwrap(
            try? engine.makeJob(
                for: [
                    SelectedAudioFile(url: tempDirectory.appendingPathComponent("intro.wav")),
                    SelectedAudioFile(url: tempDirectory.appendingPathComponent("outro.wav"))
                ],
                format: format,
                destinationURL: destinationURL
            ).get()
        )
        try Data("replacement".utf8).write(to: job.temporaryOutputURL)

        let result = engine.start(job: job, ffmpegURL: URL(fileURLWithPath: "/bin/sh"))

        guard case let .success(handle) = result else {
            return XCTFail("Expected successful merge handle")
        }
        XCTAssertEqual(handle.waitForCompletion(), .succeeded(outputURL: destinationURL))
        XCTAssertEqual(try String(contentsOf: destinationURL), "replacement")
        XCTAssertFalse(FileManager.default.fileExists(atPath: job.temporaryOutputURL.path))
    }
}

private struct ConstantDurationProvider: InputDurationProviding {
    let durationSeconds: Double?

    func durationSeconds(for url: URL) -> Double? {
        durationSeconds
    }
}

private final class SequenceDurationProvider: InputDurationProviding {
    let values: [Double?]
    private let indexLock = NSLock()
    private var currentIndex = 0

    init(values: [Double?]) {
        self.values = values
    }

    func durationSeconds(for url: URL) -> Double? {
        indexLock.lock()
        defer { indexLock.unlock() }
        guard currentIndex < values.count else { return values.last ?? nil }
        let value = values[currentIndex]
        currentIndex += 1
        return value
    }
}
