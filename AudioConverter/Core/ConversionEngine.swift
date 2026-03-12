import Foundation

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

    func run(job: ConversionJob, ffmpegURL: URL) -> ConversionItemState {
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            return .failed(reason: .ffmpegUnavailable)
        }

        let arguments = FFmpegCommandBuilder.makeArguments(
            inputURL: job.inputFile.url,
            outputURL: job.temporaryOutputURL,
            outputFormat: job.outputFormat
        )

        do {
            let result = try ffmpegRunner.run(ffmpegURL: ffmpegURL, arguments: arguments)

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
        } catch {
            fileManager.removeItemIfPresent(at: job.temporaryOutputURL)
            return .failed(reason: .processLaunchFailed(error.localizedDescription))
        }
    }
}
