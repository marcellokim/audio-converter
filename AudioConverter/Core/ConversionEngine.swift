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
                    FFmpegExecutionLifecycle.finish(
                        runningTask: runningTask,
                        outputURL: job.outputURL,
                        temporaryOutputURL: job.temporaryOutputURL,
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
    FFmpegExecutionLifecycle.makeProgress(
        from: event,
        totalDurationSeconds: durationSeconds,
        copy: .conversion
    )
}
