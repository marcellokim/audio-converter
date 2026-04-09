import Foundation

enum AppStateWorkflowRules {
    static func canOpenFiles(startupState: StartupState, isConverting: Bool) -> Bool {
        startupState == .ready && !isConverting
    }

    static func canRemoveSelectedFiles(isConverting: Bool, selectedFileCount: Int) -> Bool {
        !isConverting && selectedFileCount > 0
    }

    static func canRetryStartupChecks(startupState: StartupState) -> Bool {
        if case .startupError = startupState {
            return true
        }

        return false
    }

    static func canStartConversion(
        operationMode: AppState.OperationMode,
        startupState: StartupState,
        isConverting: Bool,
        selectedFileCount: Int,
        validationState: ValidationState
    ) -> Bool {
        guard operationMode == .batchConvert else {
            return false
        }

        guard canOpenFiles(startupState: startupState, isConverting: isConverting), selectedFileCount > 0 else {
            return false
        }

        return validationState.supportedFormat != nil
    }

    static func canChooseMergeDestination(
        operationMode: AppState.OperationMode,
        startupState: StartupState,
        isConverting: Bool,
        selectedFileCount: Int,
        validationState: ValidationState
    ) -> Bool {
        guard operationMode == .mergeIntoOne else {
            return false
        }

        guard canOpenFiles(startupState: startupState, isConverting: isConverting), selectedFileCount > 0 else {
            return false
        }

        return validationState.supportedFormat != nil
    }

    static func canStartMerge(
        operationMode: AppState.OperationMode,
        startupState: StartupState,
        isConverting: Bool,
        selectedFileCount: Int,
        validationState: ValidationState,
        hasMergeDestination: Bool
    ) -> Bool {
        guard operationMode == .mergeIntoOne else {
            return false
        }

        guard canOpenFiles(startupState: startupState, isConverting: isConverting), selectedFileCount >= 2, hasMergeDestination else {
            return false
        }

        return validationState.supportedFormat != nil
    }

    static func canCancelConversion(
        isConverting: Bool,
        isCancelling: Bool,
        hasCurrentSession: Bool
    ) -> Bool {
        isConverting && !isCancelling && hasCurrentSession
    }

    static func canReorderSelectedFiles(
        operationMode: AppState.OperationMode,
        isConverting: Bool,
        selectedFileCount: Int
    ) -> Bool {
        operationMode == .mergeIntoOne && !isConverting && selectedFileCount > 1
    }
}

enum AppStateStatusPolicy {
    static func selectionCancelledMessage(existingFileCount: Int) -> String {
        existingFileCount == 0
            ? "File selection cancelled."
            : "File selection cancelled. Keeping \(existingFileCount) loaded file(s)."
    }

    static func loadedFilesMessage(fileCount: Int, operationMode: AppState.OperationMode) -> String {
        operationMode == .mergeIntoOne
            ? "Loaded \(fileCount) source file(s) for ordered merge."
            : "Loaded \(fileCount) source file(s)."
    }

    static func mergeDestinationSelectionCancelledMessage(currentDestinationURL: URL?) -> String {
        if let currentDestinationURL {
            return "Destination selection cancelled. Keeping \(currentDestinationURL.lastPathComponent)."
        }

        return "Destination selection cancelled."
    }

    static func formatRequirementMessage(
        for validationState: ValidationState,
        supportedFormatSummary: String
    ) -> String {
        switch validationState {
        case .idle:
            return "Enter an output format such as \(supportedFormatSummary)."
        case let .invalidFormat(input):
            let normalized = FormatRegistry.normalizedKey(for: input)
            return normalized.isEmpty
                ? "Enter an output format such as \(supportedFormatSummary)."
                : "\"\(normalized)\" is not supported. Try \(supportedFormatSummary)."
        case let .valid(format):
            return "Use \(format.displayName) for the next operation."
        }
    }

    static func currentInputMessage(
        startupState: StartupState,
        operationMode: AppState.OperationMode,
        selectedFileCount: Int,
        validationState: ValidationState,
        mergeDestinationURL: URL?,
        supportedFormatSummary: String
    ) -> String {
        switch startupState {
        case .idle:
            return "Launch the app to run the bundled ffmpeg self-check."
        case .checking:
            return "Running bundled ffmpeg self-check…"
        case let .startupError(message):
            return message
        case .ready:
            switch operationMode {
            case .batchConvert:
                return batchReadyMessage(
                    selectedFileCount: selectedFileCount,
                    validationState: validationState,
                    supportedFormatSummary: supportedFormatSummary
                )
            case .mergeIntoOne:
                return mergeReadyMessage(
                    selectedFileCount: selectedFileCount,
                    validationState: validationState,
                    mergeDestinationURL: mergeDestinationURL,
                    supportedFormatSummary: supportedFormatSummary
                )
            }
        }
    }

    static func conversionStartedMessage(fileCount: Int, format: SupportedFormat) -> String {
        "Converting \(fileCount) file(s) to \(format.displayName)…"
    }

    static func mergeStartedMessage(fileCount: Int, destinationURL: URL) -> String {
        "Merging \(fileCount) file(s) into \(destinationURL.lastPathComponent)…"
    }

    static func conversionInFlightMessage(
        snapshots: [BatchStatusSnapshot],
        format: SupportedFormat
    ) -> String {
        let summary = [
            summaryCount(in: snapshots, matching: { if case .queued = $0 { return true } else { return false } }, label: "queued"),
            summaryCount(in: snapshots, matching: { if case .running = $0 { return true } else { return false } }, label: "running"),
            summaryCount(in: snapshots, matching: { if case .succeeded = $0 { return true } else { return false } }, label: "converted"),
            summaryCount(in: snapshots, matching: { if case .skipped = $0 { return true } else { return false } }, label: "skipped"),
            summaryCount(in: snapshots, matching: { if case .failed = $0 { return true } else { return false } }, label: "failed"),
            summaryCount(in: snapshots, matching: { if case .cancelled = $0 { return true } else { return false } }, label: "cancelled")
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        if summary.isEmpty {
            return "Converting \(snapshots.count) file(s) to \(format.displayName)…"
        }

        return "Converting to \(format.displayName): \(summary)."
    }

    static func mergeInFlightMessage(
        snapshots: [BatchStatusSnapshot],
        format: SupportedFormat
    ) -> String {
        guard let snapshot = snapshots.first else {
            return "Merging to \(format.displayName)…"
        }

        switch snapshot.state {
        case .queued:
            return "Preparing merge to \(format.displayName)…"
        case .running:
            return snapshot.displayedDetail.isEmpty
                ? "Merging to \(format.displayName)…"
                : snapshot.displayedDetail
        case .succeeded, .failed, .skipped, .cancelled:
            return snapshot.displayedDetail
        }
    }

    static func conversionCompletionMessage(
        snapshots: [BatchStatusSnapshot],
        format: SupportedFormat
    ) -> String {
        let convertedCount = snapshots.filter {
            if case .succeeded = $0.state {
                return true
            }
            return false
        }.count

        let skippedCount = snapshots.filter {
            if case .skipped = $0.state {
                return true
            }
            return false
        }.count

        let failedCount = snapshots.filter {
            if case .failed = $0.state {
                return true
            }
            return false
        }.count

        let cancelledCount = snapshots.filter {
            if case .cancelled = $0.state {
                return true
            }
            return false
        }.count

        let summary = [
            convertedCount > 0 ? "\(convertedCount) converted" : nil,
            skippedCount > 0 ? "\(skippedCount) skipped" : nil,
            failedCount > 0 ? "\(failedCount) failed" : nil,
            cancelledCount > 0 ? "\(cancelledCount) cancelled" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        if summary.isEmpty {
            return "Finished conversion to \(format.displayName), but no files were processed."
        }

        return "Finished conversion to \(format.displayName): \(summary)."
    }

    static func mergeCompletionMessage(
        snapshots: [BatchStatusSnapshot],
        format: SupportedFormat
    ) -> String {
        guard let snapshot = snapshots.first else {
            return "Finished merge to \(format.displayName), but no output was produced."
        }

        switch snapshot.state {
        case let .succeeded(outputURL):
            return "Finished merge to \(format.displayName): saved \(outputURL.lastPathComponent)."
        case .cancelled:
            return "Finished merge to \(format.displayName): cancelled."
        case .failed, .skipped:
            return snapshot.displayedDetail
        case .queued, .running:
            return "Merge is still in progress."
        }
    }

    private static func batchReadyMessage(
        selectedFileCount: Int,
        validationState: ValidationState,
        supportedFormatSummary: String
    ) -> String {
        switch validationState {
        case .idle:
            return selectedFileCount == 0
                ? "Bundled ffmpeg is ready. Select source files and choose an output format."
                : "Enter an output format such as \(supportedFormatSummary)."
        case .invalidFormat:
            return formatRequirementMessage(
                for: validationState,
                supportedFormatSummary: supportedFormatSummary
            )
        case let .valid(format):
            return selectedFileCount == 0
                ? "Bundled ffmpeg is ready. Select source files to convert to \(format.displayName)."
                : "Ready to convert \(selectedFileCount) file(s) to \(format.displayName)."
        }
    }

    private static func mergeReadyMessage(
        selectedFileCount: Int,
        validationState: ValidationState,
        mergeDestinationURL: URL?,
        supportedFormatSummary: String
    ) -> String {
        switch validationState {
        case .idle:
            return selectedFileCount == 0
                ? "Bundled ffmpeg is ready. Select two or more source files and choose an output format to merge."
                : "Enter an output format such as \(supportedFormatSummary)."
        case .invalidFormat:
            return formatRequirementMessage(
                for: validationState,
                supportedFormatSummary: supportedFormatSummary
            )
        case let .valid(format):
            if selectedFileCount == 0 {
                return "Bundled ffmpeg is ready. Select two or more source files to merge into one \(format.displayName) file."
            }

            if selectedFileCount == 1 {
                return "Add at least one more source file to merge into one \(format.displayName) file."
            }

            if let mergeDestinationURL {
                return "Ready to merge \(selectedFileCount) file(s) into \(mergeDestinationURL.lastPathComponent)."
            }

            return "Choose a destination for the merged \(format.displayName) file."
        }
    }

    private static func summaryCount(
        in snapshots: [BatchStatusSnapshot],
        matching predicate: (ConversionItemState) -> Bool,
        label: String
    ) -> String? {
        let count = snapshots.filter { predicate($0.state) }.count
        return count > 0 ? "\(count) \(label)" : nil
    }
}

private extension ValidationState {
    var supportedFormat: SupportedFormat? {
        if case let .valid(format) = self {
            return format
        }

        return nil
    }
}
