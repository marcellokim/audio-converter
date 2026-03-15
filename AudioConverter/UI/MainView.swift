import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                StatusBannerView(
                    title: bannerTitle,
                    message: bannerMessage,
                    isCritical: appState.startupError != nil
                )

                FileSelectionView(
                    files: selectedAudioFiles,
                    action: handleSelectFiles,
                    isEnabled: appState.canOpenFiles
                )

                FormatInputView(
                    outputFormat: $appState.outputFormat,
                    formats: FormatRegistry.allFormats,
                    isEnabled: !appState.isConverting
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Start Conversion", action: handleStartConversion)
                            .buttonStyle(.borderedProminent)
                            .disabled(!canStartConversion)

                        if appState.isConverting {
                            Button(appState.isCancelling ? "Cancelling Batch…" : "Cancel Batch", action: handleCancelConversion)
                                .buttonStyle(.bordered)
                                .disabled(!appState.canCancelConversion)
                        }

                        if appState.canRetryStartupChecks {
                            Button("Retry Startup Check", action: handleRetryStartupChecks)
                                .buttonStyle(.bordered)
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
                }

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

            Text("Batch convert audio with the bundled ffmpeg runtime, a registry-backed output format, and a reusable SwiftUI shell.")
                .foregroundStyle(.secondary)
        }
    }

    private var selectedAudioFiles: [SelectedAudioFile] {
        appState.selectedFiles.map(SelectedAudioFile.init)
    }

    private var validationState: ValidationState {
        appState.formatValidationState
    }

    private var canStartConversion: Bool {
        appState.canStartConversion
    }

    private var selectedFormat: SupportedFormat? {
        guard case let .valid(format) = validationState else {
            return nil
        }

        return format
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
                return appState.isCancelling ? "Cancelling batch" : "Converting batch"
            }

            if let format = selectedFormat {
                if selectedAudioFiles.isEmpty {
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
            return "AudioConverter is validating the bundled ffmpeg runtime before file selection and conversion become available."
        case let .startupError(message):
            return message
        case .ready:
            if appState.isConverting, let format = selectedFormat {
                let verb = appState.isCancelling ? "Cancelling" : "Rendering"
                return "\(verb) \(selectedAudioFiles.count) file(s) to \(format.displayName). \(appState.statusMessage)"
            }

            if let format = selectedFormat {
                if selectedAudioFiles.isEmpty {
                    return "The UI shell is loaded and waiting for files to render as \(format.displayName)."
                }

                return "\(selectedAudioFiles.count) file(s) are staged for \(format.displayName). \(appState.statusMessage)"
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
                return "Cancellation is in progress. Controls will re-enable when the batch finishes."
            }

            if appState.isConverting {
                return "Conversion is running. Controls will re-enable when the batch completes."
            }

            if selectedAudioFiles.isEmpty {
                return "Choose one or more source files to enable conversion."
            }

            guard let format = selectedFormat else {
                return "Enter a supported format such as \(supportedFormatsList)."
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

    private func handleStartConversion() {
        appState.startConversion()
    }

    private func handleCancelConversion() {
        appState.cancelConversion()
    }

    private func handleRetryStartupChecks() {
        appState.retryStartupChecks()
    }
}
