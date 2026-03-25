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
                    finishMergeTask(
                        runningTask,
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
    if let totalDurationSeconds, totalDurationSeconds > 0, let outTimeSeconds = event.outTimeSeconds {
        let fractionCompleted = min(max(outTimeSeconds / totalDurationSeconds, 0), 1)
        let percentComplete = Int((fractionCompleted * 100).rounded())
        return ConversionProgress(
            fractionCompleted: fractionCompleted,
            isIndeterminate: false,
            progressDetail: "\(percentComplete)% merged"
        )
    }

    if let outTimeSeconds = event.outTimeSeconds {
        return ConversionProgress(
            fractionCompleted: nil,
            isIndeterminate: true,
            progressDetail: String(format: "Merged %.1fs so far.", outTimeSeconds)
        )
    }

    guard event.progressState == "continue" else {
        return nil
    }

    return ConversionProgress(
        fractionCompleted: nil,
        isIndeterminate: true,
        progressDetail: "Merging with ffmpeg."
    )
}

private func finishMergeTask(
    _ runningTask: FFmpegTaskRunning,
    outputURL: URL,
    temporaryOutputURL: URL,
    fileManager: FileManaging
) -> ConversionItemState {
    do {
        let result = try runningTask.wait()
        return mapMergeRunResult(
            result,
            outputURL: outputURL,
            temporaryOutputURL: temporaryOutputURL,
            fileManager: fileManager
        )
    } catch {
        fileManager.removeItemIfPresent(at: temporaryOutputURL)
        return .failed(reason: .processLaunchFailed(error.localizedDescription))
    }
}

private func mapMergeRunResult(
    _ result: FFmpegRunResult,
    outputURL: URL,
    temporaryOutputURL: URL,
    fileManager: FileManaging
) -> ConversionItemState {
    if result.wasCancelled {
        fileManager.removeItemIfPresent(at: temporaryOutputURL)
        return .cancelled
    }

    guard result.terminationStatus == 0 else {
        fileManager.removeItemIfPresent(at: temporaryOutputURL)
        if result.standardError.localizedCaseInsensitiveContains("file exists") {
            return .skipped(reason: .conflictExistingOutput)
        }
        let message = result.standardError.isEmpty
            ? "ffmpeg exited with status \(result.terminationStatus)."
            : result.standardError
        return .failed(reason: .processFailed(message))
    }

    do {
        try fileManager.moveItemAtomically(at: temporaryOutputURL, to: outputURL)
        return .succeeded(outputURL: outputURL)
    } catch {
        fileManager.removeItemIfPresent(at: temporaryOutputURL)
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteFileExists {
            return .skipped(reason: .conflictExistingOutput)
        }
        return .failed(reason: .filesystem(error.localizedDescription))
    }
}
