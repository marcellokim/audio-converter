import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                operationModePicker

                StatusBannerView(
                    title: bannerTitle,
                    message: bannerMessage,
                    isCritical: appState.startupError != nil
                )

                FileSelectionView(
                    files: appState.selectedAudioFiles,
                    action: handleSelectFiles,
                    onRemove: handleRemoveSelectedFile,
                    onMoveUp: handleMoveSelectedFileUp,
                    onMoveDown: handleMoveSelectedFileDown,
                    canBrowseFiles: appState.canOpenFiles,
                    canRemoveFiles: appState.canRemoveSelectedFiles,
                    canReorderFiles: appState.canReorderSelectedFiles,
                    isMergeMode: isMergeMode
                )

                FormatInputView(
                    outputFormat: $appState.outputFormat,
                    formats: FormatRegistry.allFormats,
                    isEnabled: !appState.isConverting
                )

                primaryActionSection

                BatchStatusListView(snapshots: appState.batchSnapshots)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AudioConverter")
                .font(.largeTitle.weight(.semibold))

            Text("Batch convert audio or stage files in a deliberate order and merge them into one export with the bundled ffmpeg runtime.")
                .foregroundStyle(.secondary)
        }
    }

    private var operationModePicker: some View {
        HStack(spacing: 10) {
            modeButton(
                title: "Batch Convert",
                mode: .batchConvert,
                identifier: "mode-batch"
            )
            modeButton(
                title: "Merge into One",
                mode: .mergeIntoOne,
                identifier: "mode-merge"
            )
        }
    }

    private var primaryActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isMergeMode {
                    Button("Choose Destination", action: handleSelectMergeDestination)
                        .buttonStyle(.bordered)
                        .disabled(!appState.canChooseMergeDestination)
                        .accessibilityIdentifier("select-merge-destination")

                    if let mergeDestinationURL = appState.mergeDestinationURL {
                        Text(mergeDestinationURL.lastPathComponent)
                            .font(.custom("Menlo", size: 11))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("merge-destination-name")
                    }
                }

                Button(primaryActionTitle, action: handleStartPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canStartPrimaryAction)
                    .accessibilityIdentifier(primaryActionIdentifier)

                if appState.isConverting {
                    Button(cancelActionTitle, action: handleCancelConversion)
                        .buttonStyle(.bordered)
                        .disabled(!appState.canCancelConversion)
                        .accessibilityIdentifier(cancelActionIdentifier)
                }

                if appState.canRetryStartupChecks {
                    Button("Retry Startup Check", action: handleRetryStartupChecks)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("retry-startup-check")
                }

                Text(readinessMessage)
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.secondary)
            }

            if case let .invalidFormat(rawInput) = validationState {
                Text(invalidFormatMessage(for: rawInput))
                    .font(.custom("Menlo", size: 11))
                    .foregroundStyle(.orange)
            }

            Text(appState.statusMessage)
                .font(.custom("Menlo", size: 11))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("status-message")
        }
    }

    private func modeButton(
        title: String,
        mode: AppState.OperationMode,
        identifier: String
    ) -> some View {
        Button(title) {
            appState.operationMode = mode
        }
        .buttonStyle(mode == appState.operationMode ? .borderedProminent : .bordered)
        .disabled(appState.isConverting)
        .accessibilityIdentifier(identifier)
    }

    private var isMergeMode: Bool {
        appState.operationMode == .mergeIntoOne
    }

    private var validationState: ValidationState {
        appState.formatValidationState
    }

    private var selectedFormat: SupportedFormat? {
        guard case let .valid(format) = validationState else {
            return nil
        }

        return format
    }

    private var canStartPrimaryAction: Bool {
        isMergeMode ? appState.canStartMerge : appState.canStartConversion
    }

    private var primaryActionTitle: String {
        isMergeMode ? "Start Merge" : "Start Conversion"
    }

    private var primaryActionIdentifier: String {
        isMergeMode ? "start-merge" : "start-conversion"
    }

    private var cancelActionTitle: String {
        if isMergeMode {
            return appState.isCancelling ? "Cancelling Merge…" : "Cancel Merge"
        }

        return appState.isCancelling ? "Cancelling Batch…" : "Cancel Batch"
    }

    private var cancelActionIdentifier: String {
        isMergeMode ? "cancel-merge" : "cancel-conversion"
    }

    private var bannerTitle: String {
        switch appState.startupState {
        case .idle:
            return "Preparing launch"
        case .checking:
            return "Checking bundled ffmpeg"
        case .startupError:
            return "Startup blocked"
        case .ready:
            if appState.isConverting {
                if isMergeMode {
                    return appState.isCancelling ? "Cancelling merge" : "Merging ordered audio"
                }

                return appState.isCancelling ? "Cancelling batch" : "Converting batch"
            }

            if let format = selectedFormat {
                if isMergeMode {
                    return appState.selectedAudioFiles.count < 2
                        ? "Stage files for ordered merge"
                        : "Merge into one \(format.displayName)"
                }

                if appState.selectedAudioFiles.isEmpty {
                    return "Ready for source files"
                }

                return "Prepared for \(format.displayName)"
            }

            return "Choose a supported format"
        }
    }

    private var bannerMessage: String {
        switch appState.startupState {
        case .idle, .checking:
            return "AudioConverter is validating the bundled ffmpeg runtime before file selection and export become available."
        case let .startupError(message):
            return message
        case .ready:
            if appState.isConverting, let format = selectedFormat {
                let verb = appState.isCancelling
                    ? (isMergeMode ? "Cancelling" : "Cancelling")
                    : (isMergeMode ? "Merging" : "Rendering")
                return "\(verb) \(appState.selectedAudioFiles.count) file(s) to \(format.displayName). \(appState.statusMessage)"
            }

            if let format = selectedFormat {
                if isMergeMode {
                    if appState.selectedAudioFiles.isEmpty {
                        return "Stage files, set their order, choose a destination, and merge into one \(format.displayName) export."
                    }

                    return "\(appState.selectedAudioFiles.count) ordered file(s) are staged for one \(format.displayName) export. \(appState.statusMessage)"
                }

                if appState.selectedAudioFiles.isEmpty {
                    return "The UI shell is loaded and waiting for files to render as \(format.displayName)."
                }

                return "\(appState.selectedAudioFiles.count) file(s) are staged for \(format.displayName). \(appState.statusMessage)"
            }

            return "Supported formats come from the built-in registry: \(supportedFormatsList)."
        }
    }

    private var readinessMessage: String {
        switch appState.startupState {
        case .idle, .checking:
            return "Wait for the startup self-check to finish."
        case .startupError:
            return "Retry the startup self-check to continue."
        case .ready:
            if appState.isCancelling {
                return isMergeMode
                    ? "Cancellation is in progress. Controls will re-enable when the merge finishes."
                    : "Cancellation is in progress. Controls will re-enable when the batch finishes."
            }

            if appState.isConverting {
                return isMergeMode
                    ? "Merge is running. Controls will re-enable when the export completes."
                    : "Conversion is running. Controls will re-enable when the batch completes."
            }

            if appState.selectedAudioFiles.isEmpty {
                return isMergeMode
                    ? "Choose two or more source files to enable ordered merge."
                    : "Choose one or more source files to enable conversion."
            }

            guard let format = selectedFormat else {
                return "Enter a supported format such as \(supportedFormatsList)."
            }

            if isMergeMode {
                if appState.selectedAudioFiles.count < 2 {
                    return "Add at least one more source file to enable ordered merge."
                }

                if appState.mergeDestinationURL == nil {
                    return "Choose a destination before starting the merged \(format.displayName) export."
                }

                return "The ordered merge will export one \(format.outputExtension.uppercased()) file."
            }

            return "Conversion will render beside the source files as \(format.outputExtension.uppercased())."
        }
    }

    private var supportedFormatsList: String {
        FormatRegistry.allFormats.map(\.id).joined(separator: ", ")
    }

    private func invalidFormatMessage(for rawInput: String) -> String {
        let candidate = FormatRegistry.normalizedKey(for: rawInput)
        let token = candidate.isEmpty ? "That format" : "\"\(candidate)\""
        return "\(token) is not in the registry yet. Try \(supportedFormatsList)."
    }

    private func handleSelectFiles() {
        appState.selectFiles()
    }

    private func handleSelectMergeDestination() {
        appState.selectMergeDestination()
    }

    private func handleStartPrimaryAction() {
        appState.startPrimaryAction()
    }

    private func handleRemoveSelectedFile(_ file: SelectedAudioFile) {
        appState.removeSelectedFile(file)
    }

    private func handleMoveSelectedFileUp(_ file: SelectedAudioFile) {
        appState.moveSelectedFileUp(file)
    }

    private func handleMoveSelectedFileDown(_ file: SelectedAudioFile) {
        appState.moveSelectedFileDown(file)
    }

    private func handleCancelConversion() {
        appState.cancelConversion()
    }

    private func handleRetryStartupChecks() {
        appState.retryStartupChecks()
    }
}
