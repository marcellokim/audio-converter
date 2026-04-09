import Foundation

struct MergeExportJob {
    let inputFiles: [SelectedAudioFile]
    let outputFormat: SupportedFormat
    let outputURL: URL
    let temporaryOutputURL: URL
    let totalDurationSeconds: Double?
}

struct MergeExportEngine {
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

    func makeJob(
        for files: [SelectedAudioFile],
        format: SupportedFormat,
        destinationURL: URL
    ) -> Result<MergeExportJob, ConversionItemState> {
        guard files.count >= 2 else {
            return .failure(.failed(reason: .validation("Select at least two source audio files before merging.")))
        }

        if fileManager.fileExists(at: destinationURL) {
            return .failure(.skipped(reason: .conflictExistingOutput))
        }

        let temporaryOutputURL = fileManager.makeTemporaryOutputURL(for: destinationURL)
        let durations = files.map { inputDurationProvider.durationSeconds(for: $0.url) }
        let totalDurationSeconds: Double?
        if durations.allSatisfy({ $0 != nil }) {
            totalDurationSeconds = durations.compactMap { $0 }.reduce(0, +)
        } else {
            totalDurationSeconds = nil
        }

        return .success(
            MergeExportJob(
                inputFiles: files,
                outputFormat: format,
                outputURL: destinationURL,
                temporaryOutputURL: temporaryOutputURL,
                totalDurationSeconds: totalDurationSeconds
            )
        )
    }

    func start(
        job: MergeExportJob,
        ffmpegURL: URL,
        onProgress: ((ConversionProgress) -> Void)? = nil
    ) -> Result<ConversionExecutionHandle, ConversionItemState> {
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            return .failure(.failed(reason: .ffmpegUnavailable))
        }

        let arguments = FFmpegCommandBuilder.makeMergeArguments(
            inputURLs: job.inputFiles.map(\.url),
            outputURL: job.temporaryOutputURL,
            outputFormat: job.outputFormat
        )

        do {
            let runningTask = try ffmpegRunner.start(ffmpegURL: ffmpegURL, arguments: arguments)
            if let onProgress {
                runningTask.setProgressHandler { event in
                    guard let progress = makeMergeProgress(from: event, totalDurationSeconds: job.totalDurationSeconds) else {
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
}

private func makeMergeProgress(
    from event: FFmpegProgressEvent,
    totalDurationSeconds: Double?
) -> ConversionProgress? {
    FFmpegExecutionLifecycle.makeProgress(
        from: event,
        totalDurationSeconds: totalDurationSeconds,
        copy: .merge
    )
}
