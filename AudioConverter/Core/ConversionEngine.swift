import Foundation

struct ConversionProgress: Equatable {
    let fractionCompleted: Double?
    let isIndeterminate: Bool
    let progressDetail: String
}

final class ConversionExecutionHandle {
    private let waitForResult: () -> ConversionItemState
    private let cancelImpl: () -> Void

    init(waitForResult: @escaping () -> ConversionItemState, cancel: @escaping () -> Void) {
        self.waitForResult = waitForResult
        self.cancelImpl = cancel
    }

    func waitForCompletion() -> ConversionItemState {
        waitForResult()
    }

    func cancel() {
        cancelImpl()
    }
}

struct ConversionEngine {
    private let fileManager: FileManaging
    private let ffmpegRunner: FFmpegRunning
    private let inputDurationProvider: InputDurationProviding

    init(
        fileManager: FileManaging = DefaultFileManagerAdapter(),
        ffmpegRunner: FFmpegRunning = FFmpegRunner(),
        inputDurationProvider: InputDurationProviding = InputDurationProvider()
    ) {
        self.fileManager = fileManager
        self.ffmpegRunner = ffmpegRunner
        self.inputDurationProvider = inputDurationProvider
    }

    func makeJob(for file: SelectedAudioFile, format: SupportedFormat) -> Result<ConversionJob, ConversionItemState> {
        switch OutputPathResolver.resolveDestination(for: file.url, format: format) {
        case let .success(outputURL):
            if fileManager.fileExists(at: outputURL) {
                return .failure(.skipped(reason: .conflictExistingOutput))
            }

            let temporaryOutputURL = fileManager.makeTemporaryOutputURL(for: outputURL)
            return .success(
                ConversionJob(
                    inputFile: file,
                    outputFormat: format,
                    outputURL: outputURL,
                    temporaryOutputURL: temporaryOutputURL
                )
            )

        case let .failure(reason):
            return .failure(.skipped(reason: reason))
        }
    }

    func start(
        job: ConversionJob,
        ffmpegURL: URL,
        onProgress: ((ConversionProgress) -> Void)? = nil
    ) -> Result<ConversionExecutionHandle, ConversionItemState> {
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            return .failure(.failed(reason: .ffmpegUnavailable))
        }

        let durationSeconds = inputDurationProvider.durationSeconds(for: job.inputFile.url)
        let arguments = FFmpegCommandBuilder.makeArguments(
            inputURL: job.inputFile.url,
            outputURL: job.temporaryOutputURL,
            outputFormat: job.outputFormat
        )

        do {
            let runningTask = try ffmpegRunner.start(ffmpegURL: ffmpegURL, arguments: arguments)
            if let onProgress {
                runningTask.setProgressHandler { event in
                    guard let progress = makeConversionProgress(from: event, durationSeconds: durationSeconds) else {
                        return
                    }

                    onProgress(progress)
                }
            }
            let handle = ConversionExecutionHandle(
                waitForResult: {
                    finishRunningTask(
                        runningTask,
                        job: job,
                        fileManager: fileManager
                    )
                },
                cancel: {
                    runningTask.cancel()
                }
            )
            return .success(handle)
        } catch {
            fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
            return .failure(.failed(reason: .processLaunchFailed(error.localizedDescription)))
        }
    }

    func run(job: ConversionJob, ffmpegURL: URL) -> ConversionItemState {
        switch start(job: job, ffmpegURL: ffmpegURL) {
        case let .success(handle):
            return handle.waitForCompletion()
        case let .failure(state):
            return state
        }
    }
}

private func makeConversionProgress(
    from event: FFmpegProgressEvent,
    durationSeconds: Double?
) -> ConversionProgress? {
    if let durationSeconds, durationSeconds > 0, let outTimeSeconds = event.outTimeSeconds {
        let fractionCompleted = min(max(outTimeSeconds / durationSeconds, 0), 1)
        let percentComplete = Int((fractionCompleted * 100).rounded())
        return ConversionProgress(
            fractionCompleted: fractionCompleted,
            isIndeterminate: false,
            progressDetail: "\(percentComplete)% complete"
        )
    }

    if let outTimeSeconds = event.outTimeSeconds {
        return ConversionProgress(
            fractionCompleted: nil,
            isIndeterminate: true,
            progressDetail: String(format: "Rendered %.1fs so far.", outTimeSeconds)
        )
    }

    guard event.progressState == "continue" else {
        return nil
    }

    return ConversionProgress(
        fractionCompleted: nil,
        isIndeterminate: true,
        progressDetail: "Rendering with ffmpeg."
    )
}

private func finishRunningTask(
    _ runningTask: FFmpegTaskRunning,
    job: ConversionJob,
    fileManager: FileManaging
) -> ConversionItemState {
    do {
        let result = try runningTask.wait()
        return mapRunResult(result, job: job, fileManager: fileManager)
    } catch {
        fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
        return .failed(reason: .processLaunchFailed(error.localizedDescription))
    }
}

private func mapRunResult(
    _ result: FFmpegRunResult,
    job: ConversionJob,
    fileManager: FileManaging
) -> ConversionItemState {
    if result.wasCancelled {
        fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
        return .cancelled
    }

    guard result.terminationStatus == 0 else {
        fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
        if result.standardError.localizedCaseInsensitiveContains("file exists") {
            return .skipped(reason: .conflictExistingOutput)
        }
        let message = result.standardError.isEmpty ? "ffmpeg exited with status \(result.terminationStatus)." : result.standardError
        return .failed(reason: .processFailed(message))
    }

    do {
        try fileManager.moveItemAtomically(at: job.temporaryOutputURL, to: job.outputURL)
        return .succeeded(outputURL: job.outputURL)
    } catch {
        fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteFileExists {
            return .skipped(reason: .conflictExistingOutput)
        }
        return .failed(reason: .filesystem(error.localizedDescription))
    }
}
