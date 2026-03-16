import Foundation

protocol BatchConversionSessioning: AnyObject {
    func start()
    func cancelAll()
}

extension ConversionCoordinatorSession: BatchConversionSessioning {}

final class AppState: ObservableObject {
    enum FFmpegResolution {
        case ready(URL)
        case failure(String)
    }

    typealias FFmpegResolver = () -> FFmpegResolution
    typealias CapabilityValidator = (URL) -> StartupState
    typealias FileSelector = () -> [SelectedAudioFile]
    typealias ConversionSessionFactory = (
        [SelectedAudioFile],
        SupportedFormat,
        URL,
        @escaping ([BatchStatusSnapshot]) -> Void,
        @escaping ([BatchStatusSnapshot]) -> Void
    ) -> any BatchConversionSessioning

    @Published var selectedFiles: [URL] = [] {
        didSet {
            refreshStatusMessageForCurrentInputs()
        }
    }

    @Published var outputFormat: String = "mp3" {
        didSet {
            refreshStatusMessageForCurrentInputs()
        }
    }

    @Published var statusMessage: String = "Launch the app to run the bundled ffmpeg self-check."
    @Published var startupError: String?
    @Published private(set) var startupState: StartupState = .idle
    @Published private(set) var batchSnapshots: [BatchStatusSnapshot] = []
    @Published private(set) var isConverting = false
    @Published private(set) var isCancelling = false

    private let resolveFFmpegURL: FFmpegResolver
    private let validateStartupCapabilities: CapabilityValidator
    private let selectAudioFiles: FileSelector
    private let makeConversionSession: ConversionSessionFactory

    private var ffmpegURL: URL?
    private var hasPerformedStartupChecks = false
    private var currentSession: (any BatchConversionSessioning)?

    init(
        resolveFFmpegURL: @escaping FFmpegResolver = AppState.defaultResolveFFmpegURL,
        validateStartupCapabilities: @escaping CapabilityValidator = { FFmpegStartupSelfCheck().validateCapabilities(for: $0) },
        selectAudioFiles: @escaping FileSelector = { OpenPanelPresenter().selectFiles() },
        makeConversionSession: @escaping ConversionSessionFactory = { files, format, ffmpegURL, onUpdate, onCompletion in
            ConversionCoordinator().makeSession(
                files: files,
                format: format,
                ffmpegURL: ffmpegURL,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }
    ) {
        self.resolveFFmpegURL = resolveFFmpegURL
        self.validateStartupCapabilities = validateStartupCapabilities
        self.selectAudioFiles = selectAudioFiles
        self.makeConversionSession = makeConversionSession
    }

    var selectedAudioFiles: [SelectedAudioFile] {
        selectedFiles.map(SelectedAudioFile.init)
    }

    var formatValidationState: ValidationState {
        let trimmed = outputFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .idle
        }

        return FormatValidator.validate(outputFormat: trimmed)
    }

    var canOpenFiles: Bool {
        startupState == .ready && !isConverting
    }

    var canRemoveSelectedFiles: Bool {
        !isConverting && !selectedFiles.isEmpty
    }

    var canRetryStartupChecks: Bool {
        if case .startupError = startupState {
            return true
        }

        return false
    }

    var canStartConversion: Bool {
        guard canOpenFiles, !selectedFiles.isEmpty else {
            return false
        }

        guard case .valid = formatValidationState else {
            return false
        }

        return true
    }

    var canCancelConversion: Bool {
        isConverting && !isCancelling && currentSession != nil
    }

    func performStartupChecksIfNeeded() {
        guard !hasPerformedStartupChecks else {
            return
        }

        hasPerformedStartupChecks = true
        performStartupChecks()
    }

    func retryStartupChecks() {
        guard canRetryStartupChecks else {
            return
        }

        performStartupChecks()
    }

    func performStartupChecks() {
        guard startupState != .checking else {
            return
        }

        startupState = .checking
        startupError = nil
        ffmpegURL = nil
        batchSnapshots = []
        statusMessage = "Running bundled ffmpeg self-check…"

        let resolveFFmpegURL = self.resolveFFmpegURL
        let validateStartupCapabilities = self.validateStartupCapabilities

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let nextState: StartupState
            let resolvedFFmpegURL: URL?

            switch resolveFFmpegURL() {
            case let .ready(url):
                let result = validateStartupCapabilities(url)
                nextState = result
                resolvedFFmpegURL = result == .ready ? url : nil
            case let .failure(message):
                nextState = .startupError(message)
                resolvedFFmpegURL = nil
            }

            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.startupState = nextState
                self.ffmpegURL = resolvedFFmpegURL

                switch nextState {
                case .ready:
                    self.startupError = nil
                    self.refreshStatusMessageForCurrentInputs()
                case let .startupError(message):
                    self.startupError = message
                    self.statusMessage = message
                case .idle:
                    self.startupError = nil
                    self.refreshStatusMessageForCurrentInputs()
                case .checking:
                    break
                }
            }
        }
    }

    func selectFiles() {
        guard canOpenFiles else {
            return
        }

        let files = selectAudioFiles()
        guard !files.isEmpty else {
            statusMessage = selectedFiles.isEmpty
                ? "File selection cancelled."
                : "File selection cancelled. Keeping \(selectedFiles.count) loaded file(s)."
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        selectedFiles = files.map(\.url)
        statusMessage = "Loaded \(files.count) source file(s)."
        refreshStatusMessageForCurrentInputs()
    }

    func removeSelectedFile(_ file: SelectedAudioFile) {
        guard canRemoveSelectedFiles else {
            return
        }

        guard selectedFiles.contains(file.url) else {
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        selectedFiles.removeAll { $0 == file.url }
    }

    func startConversion() {
        guard !isConverting else {
            return
        }

        guard startupState == .ready else {
            statusMessage = startupError ?? "Bundled ffmpeg is not ready yet."
            return
        }

        let files = selectedAudioFiles
        guard !files.isEmpty else {
            statusMessage = "Select one or more source audio files before converting."
            return
        }

        guard let ffmpegURL else {
            statusMessage = "Bundled ffmpeg binary is unavailable."
            return
        }

        let format: SupportedFormat
        switch formatValidationState {
        case let .valid(value):
            format = value
        case let .invalidFormat(input):
            let normalized = FormatRegistry.normalizedKey(for: input)
            statusMessage = normalized.isEmpty
                ? "Enter an output format such as \(Self.supportedFormatSummary)."
                : "\"\(normalized)\" is not supported. Try \(Self.supportedFormatSummary)."
            return
        case .idle:
            statusMessage = "Enter an output format such as \(Self.supportedFormatSummary)."
            return
        }

        isConverting = true
        isCancelling = false
        statusMessage = "Converting \(files.count) file(s) to \(format.displayName)…"
        batchSnapshots = []

        let session = makeConversionSession(
            files,
            format,
            ffmpegURL,
            { [weak self] snapshots in
                self?.performOnMain {
                    guard let self else {
                        return
                    }

                    self.batchSnapshots = snapshots
                    if self.isConverting {
                        self.statusMessage = self.isCancelling
                            ? "Cancelling current batch…"
                            : self.makeInFlightStatusMessage(for: snapshots, format: format)
                    }
                }
            },
            { [weak self] snapshots in
                self?.performOnMain {
                    guard let self else {
                        return
                    }

                    self.isConverting = false
                    self.isCancelling = false
                    self.currentSession = nil
                    self.batchSnapshots = snapshots
                    self.statusMessage = self.makeCompletionStatusMessage(for: snapshots, format: format)
                }
            }
        )

        currentSession = session
        session.start()
    }

    func cancelConversion() {
        guard let currentSession, canCancelConversion else {
            return
        }

        isCancelling = true
        statusMessage = "Cancelling current batch…"
        currentSession.cancelAll()
    }

    private func refreshStatusMessageForCurrentInputs() {
        guard !isConverting else {
            return
        }

        switch startupState {
        case .idle:
            statusMessage = "Launch the app to run the bundled ffmpeg self-check."
        case .checking:
            statusMessage = "Running bundled ffmpeg self-check…"
        case let .startupError(message):
            statusMessage = message
        case .ready:
            switch formatValidationState {
            case .idle:
                statusMessage = selectedFiles.isEmpty
                    ? "Bundled ffmpeg is ready. Select source files and choose an output format."
                    : "Enter an output format such as \(Self.supportedFormatSummary)."
            case let .invalidFormat(input):
                let normalized = FormatRegistry.normalizedKey(for: input)
                statusMessage = normalized.isEmpty
                    ? "Enter an output format such as \(Self.supportedFormatSummary)."
                    : "\"\(normalized)\" is not supported. Try \(Self.supportedFormatSummary)."
            case let .valid(format):
                statusMessage = selectedFiles.isEmpty
                    ? "Bundled ffmpeg is ready. Select source files to convert to \(format.displayName)."
                    : "Ready to convert \(selectedFiles.count) file(s) to \(format.displayName)."
            }
        }
    }

    private func makeCompletionStatusMessage(for snapshots: [BatchStatusSnapshot], format: SupportedFormat) -> String {
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

    private func makeInFlightStatusMessage(for snapshots: [BatchStatusSnapshot], format: SupportedFormat) -> String {
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

    private func summaryCount(
        in snapshots: [BatchStatusSnapshot],
        matching predicate: (ConversionItemState) -> Bool,
        label: String
    ) -> String? {
        let count = snapshots.filter { predicate($0.state) }.count
        return count > 0 ? "\(count) \(label)" : nil
    }

    private static var supportedFormatSummary: String {
        FormatRegistry.allFormats.map(\.id).joined(separator: ", ")
    }

    private func clearBatchSnapshotsForSelectionMutation() {
        guard !isConverting, !batchSnapshots.isEmpty else {
            return
        }

        batchSnapshots = []
    }

    private func performOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private static func defaultResolveFFmpegURL() -> FFmpegResolution {
        switch FFmpegBinaryResolver.resolve() {
        case .ready:
            guard let url = FFmpegBinaryResolver.bundledBinaryURL() else {
                return .failure("Bundled ffmpeg binary is missing.")
            }
            return .ready(url)
        case let .startupError(message):
            return .failure(message)
        case .idle, .checking:
            return .failure("Bundled ffmpeg binary is unavailable.")
        }
    }
}
