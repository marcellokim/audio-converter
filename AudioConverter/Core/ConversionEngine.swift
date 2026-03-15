import Foundation

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

    init(
        fileManager: FileManaging = DefaultFileManagerAdapter(),
        ffmpegRunner: FFmpegRunning = FFmpegRunner()
    ) {
        self.fileManager = fileManager
        self.ffmpegRunner = ffmpegRunner
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

    func start(job: ConversionJob, ffmpegURL: URL) -> Result<ConversionExecutionHandle, ConversionItemState> {
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            return .failure(.failed(reason: .ffmpegUnavailable))
        }

        let arguments = FFmpegCommandBuilder.makeArguments(
            inputURL: job.inputFile.url,
            outputURL: job.temporaryOutputURL,
            outputFormat: job.outputFormat
        )

        do {
            let runningTask = try ffmpegRunner.start(ffmpegURL: ffmpegURL, arguments: arguments)
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
