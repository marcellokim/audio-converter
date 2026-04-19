import Foundation

enum FFmpegExecutionLifecycle {
    enum ExistingOutputPolicy {
        case avoidOverwrite
        case overwriteExisting
    }

    struct ProgressCopy {
        let percentSuffix: String
        let elapsedPrefix: String
        let fallbackDetail: String

        static let conversion = Self(
            percentSuffix: "complete",
            elapsedPrefix: "Rendered",
            fallbackDetail: "Rendering with ffmpeg."
        )

        static let merge = Self(
            percentSuffix: "merged",
            elapsedPrefix: "Merged",
            fallbackDetail: "Merging with ffmpeg."
        )
    }

    static func makeProgress(
        from event: FFmpegProgressEvent,
        totalDurationSeconds: Double?,
        copy: ProgressCopy
    ) -> ConversionProgress? {
        if let totalDurationSeconds, totalDurationSeconds > 0, let outTimeSeconds = event.outTimeSeconds {
            let fractionCompleted = min(max(outTimeSeconds / totalDurationSeconds, 0), 1)
            let percentComplete = Int((fractionCompleted * 100).rounded())
            return ConversionProgress(
                fractionCompleted: fractionCompleted,
                isIndeterminate: false,
                progressDetail: "\(percentComplete)% \(copy.percentSuffix)"
            )
        }

        if let outTimeSeconds = event.outTimeSeconds {
            return ConversionProgress(
                fractionCompleted: nil,
                isIndeterminate: true,
                progressDetail: String(format: "%@ %.1fs so far.", copy.elapsedPrefix, outTimeSeconds)
            )
        }

        guard event.progressState == "continue" else {
            return nil
        }

        return ConversionProgress(
            fractionCompleted: nil,
            isIndeterminate: true,
            progressDetail: copy.fallbackDetail
        )
    }

    static func finish(
        runningTask: FFmpegTaskRunning,
        outputURL: URL,
        temporaryOutputURL: URL,
        fileManager: FileManaging,
        existingOutputPolicy: ExistingOutputPolicy = .avoidOverwrite
    ) -> ConversionItemState {
        do {
            let result = try runningTask.wait()
            return mapRunResult(
                result,
                outputURL: outputURL,
                temporaryOutputURL: temporaryOutputURL,
                fileManager: fileManager,
                existingOutputPolicy: existingOutputPolicy
            )
        } catch {
            fileManager.removeItemIfPresent(at: temporaryOutputURL)
            return .failed(reason: .processLaunchFailed(error.localizedDescription))
        }
    }

    private static func mapRunResult(
        _ result: FFmpegRunResult,
        outputURL: URL,
        temporaryOutputURL: URL,
        fileManager: FileManaging,
        existingOutputPolicy: ExistingOutputPolicy
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
            let message = result.standardError.isEmpty ? "ffmpeg exited with status \(result.terminationStatus)." : result.standardError
            return .failed(reason: .processFailed(message))
        }

        do {
            switch existingOutputPolicy {
            case .avoidOverwrite:
                try fileManager.moveItemAtomically(at: temporaryOutputURL, to: outputURL)
            case .overwriteExisting:
                try fileManager.replaceItemAtomically(at: temporaryOutputURL, to: outputURL)
            }
            return .succeeded(outputURL: outputURL)
        } catch {
            fileManager.removeItemIfPresent(at: temporaryOutputURL)
            if existingOutputPolicy == .avoidOverwrite,
               let cocoaError = error as? CocoaError,
               cocoaError.code == .fileWriteFileExists {
                return .skipped(reason: .conflictExistingOutput)
            }
            return .failed(reason: .filesystem(error.localizedDescription))
        }
    }
}
