import Foundation

protocol BatchConversionSessioning: AnyObject {
    func start()
    func cancelAll()
}

extension ConversionCoordinatorSession: BatchConversionSessioning {}
final class AppState: ObservableObject {
    private static let preferredFormatDefaultsKey = "AudioConverter.preferredFormat"
    private static let preferredOperationModeDefaultsKey = "AudioConverter.preferredOperationMode"

    enum FFmpegResolution {
        case ready(URL)
        case failure(String)
    }

    enum OperationMode: String, CaseIterable, Identifiable {
        case batchConvert
        case mergeIntoOne

        var id: String { rawValue }
    }

    typealias FFmpegResolver = () -> FFmpegResolution
    typealias CapabilityValidator = (URL) -> StartupState
    typealias FileSelector = () -> [SelectedAudioFile]
    typealias MergeDestinationSelector = ([SelectedAudioFile], SupportedFormat) -> URL?
    typealias ConversionSessionFactory = (
        [SelectedAudioFile],
        SupportedFormat,
        URL,
        @escaping ([BatchStatusSnapshot]) -> Void,
        @escaping ([BatchStatusSnapshot]) -> Void
    ) -> any BatchConversionSessioning
    typealias MergeSessionFactory = (
        [SelectedAudioFile],
        SupportedFormat,
        URL,
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
            preferencesStore.set(outputFormat, forKey: Self.preferredFormatDefaultsKey)
            refreshStatusMessageForCurrentInputs()
        }
    }

    @Published var operationMode: OperationMode = .batchConvert {
        didSet {
            preferencesStore.set(operationMode.rawValue, forKey: Self.preferredOperationModeDefaultsKey)
            guard operationMode != oldValue else {
                return
            }

            clearBatchSnapshotsForSelectionMutation()
            refreshStatusMessageForCurrentInputs()
        }
    }

    @Published var statusMessage: String = "Launch the app to run the bundled ffmpeg self-check."
    @Published var startupError: String?
    @Published private(set) var startupState: StartupState = .idle
    @Published private(set) var batchSnapshots: [BatchStatusSnapshot] = []
    @Published private(set) var isConverting = false
    @Published private(set) var isCancelling = false
    @Published private(set) var mergeDestinationURL: URL?

    private let resolveFFmpegURL: FFmpegResolver
    private let validateStartupCapabilities: CapabilityValidator
    private let selectAudioFiles: FileSelector
    private let selectMergeDestinationURL: MergeDestinationSelector
    private let makeConversionSession: ConversionSessionFactory
    private let makeMergeSession: MergeSessionFactory
    private let preferencesStore: UserDefaults

    private var ffmpegURL: URL?
    private var hasPerformedStartupChecks = false
    private var currentSession: (any BatchConversionSessioning)?

    init(
        resolveFFmpegURL: @escaping FFmpegResolver = AppState.defaultResolveFFmpegURL,
        validateStartupCapabilities: @escaping CapabilityValidator = { FFmpegStartupSelfCheck().validateCapabilities(for: $0) },
        selectAudioFiles: @escaping FileSelector = { OpenPanelPresenter().selectFiles() },
        selectMergeDestinationURL: @escaping MergeDestinationSelector = { files, format in
            SavePanelPresenter().chooseDestination(
                for: format,
                suggestedBaseName: files.first?.url.deletingPathExtension().lastPathComponent ?? "merged-audio"
            )
        },
        preferencesStore: UserDefaults = .standard,
        makeConversionSession: @escaping ConversionSessionFactory = { files, format, ffmpegURL, onUpdate, onCompletion in
            ConversionCoordinator().makeSession(
                files: files,
                format: format,
                ffmpegURL: ffmpegURL,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        },
        makeMergeSession: @escaping MergeSessionFactory = { files, format, destinationURL, ffmpegURL, onUpdate, onCompletion in
            MergeExportSession(
                files: files,
                format: format,
                destinationURL: destinationURL,
                ffmpegURL: ffmpegURL,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }
    ) {
        self.resolveFFmpegURL = resolveFFmpegURL
        self.validateStartupCapabilities = validateStartupCapabilities
        self.selectAudioFiles = selectAudioFiles
        self.selectMergeDestinationURL = selectMergeDestinationURL
        self.preferencesStore = preferencesStore
        self.makeConversionSession = makeConversionSession
        self.makeMergeSession = makeMergeSession
        self.outputFormat = Self.restorePreferredFormat(from: preferencesStore)
        self.operationMode = Self.restorePreferredOperationMode(from: preferencesStore)
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
        guard operationMode == .batchConvert else {
            return false
        }

        guard canOpenFiles, !selectedFiles.isEmpty else {
            return false
        }

        guard case .valid = formatValidationState else {
            return false
        }

        return true
    }

    var canChooseMergeDestination: Bool {
        guard operationMode == .mergeIntoOne else {
            return false
        }

        guard canOpenFiles, !selectedFiles.isEmpty else {
            return false
        }

        guard case .valid = formatValidationState else {
            return false
        }

        return true
    }

    var canStartMerge: Bool {
        guard operationMode == .mergeIntoOne else {
            return false
        }

        guard canOpenFiles, selectedFiles.count >= 2, mergeDestinationURL != nil else {
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

    var canReorderSelectedFiles: Bool {
        operationMode == .mergeIntoOne && !isConverting && selectedFiles.count > 1
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
        statusMessage = operationMode == .mergeIntoOne
            ? "Loaded \(files.count) source file(s) for ordered merge."
            : "Loaded \(files.count) source file(s)."
        refreshStatusMessageForCurrentInputs()
    }

    func selectMergeDestination() {
        guard canChooseMergeDestination else {
            return
        }

        let files = selectedAudioFiles
        guard !files.isEmpty else {
            statusMessage = "Select one or more source audio files before choosing a merge destination."
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

        let destinationURL = selectMergeDestinationURL(files, format)
        guard let destinationURL else {
            if let mergeDestinationURL {
                statusMessage = "Destination selection cancelled. Keeping \(mergeDestinationURL.lastPathComponent)."
            } else {
                statusMessage = "Destination selection cancelled."
            }
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        mergeDestinationURL = destinationURL
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

    func clearAllFiles() {
        guard canRemoveSelectedFiles else {
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        selectedFiles = []
        mergeDestinationURL = nil
        refreshStatusMessageForCurrentInputs()
    }

    func moveSelectedFileUp(_ file: SelectedAudioFile) {
        moveSelectedFile(file, by: -1)
    }

    func moveSelectedFileDown(_ file: SelectedAudioFile) {
        moveSelectedFile(file, by: 1)
    }

    func startPrimaryAction() {
        switch operationMode {
        case .batchConvert:
            startConversion()
        case .mergeIntoOne:
            startMerge()
        }
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

    func startMerge() {
        guard !isConverting else {
            return
        }

        guard startupState == .ready else {
            statusMessage = startupError ?? "Bundled ffmpeg is not ready yet."
            return
        }

        let files = selectedAudioFiles
        guard files.count >= 2 else {
            statusMessage = "Select at least two source audio files before merging."
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

        guard let mergeDestinationURL else {
            statusMessage = "Choose a destination for the merged \(format.displayName) file."
            return
        }

        isConverting = true
        isCancelling = false
        statusMessage = "Merging \(files.count) file(s) into \(mergeDestinationURL.lastPathComponent)…"
        batchSnapshots = []

        let session = makeMergeSession(
            files,
            format,
            mergeDestinationURL,
            ffmpegURL,
            { [weak self] snapshots in
                self?.performOnMain {
                    guard let self else {
                        return
                    }

                    self.batchSnapshots = snapshots
                    if self.isConverting {
                        self.statusMessage = self.isCancelling
                            ? "Cancelling current merge…"
                            : self.makeMergeInFlightStatusMessage(for: snapshots, format: format)
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
                    self.statusMessage = self.makeMergeCompletionStatusMessage(for: snapshots, format: format)
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
        statusMessage = operationMode == .mergeIntoOne
            ? "Cancelling current merge…"
            : "Cancelling current batch…"
        currentSession.cancelAll()
    }

    private func moveSelectedFile(_ file: SelectedAudioFile, by delta: Int) {
        guard canReorderSelectedFiles,
              let currentIndex = selectedFiles.firstIndex(of: file.url) else {
            return
        }

        let destinationIndex = currentIndex + delta
        guard selectedFiles.indices.contains(destinationIndex) else {
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        var nextFiles = selectedFiles
        let movedFile = nextFiles.remove(at: currentIndex)
        nextFiles.insert(movedFile, at: destinationIndex)
        selectedFiles = nextFiles
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
            switch operationMode {
            case .batchConvert:
                refreshBatchStatusMessage()
            case .mergeIntoOne:
                refreshMergeStatusMessage()
            }
        }
    }

    private func refreshBatchStatusMessage() {
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

    private func refreshMergeStatusMessage() {
        switch formatValidationState {
        case .idle:
            statusMessage = selectedFiles.isEmpty
                ? "Bundled ffmpeg is ready. Select two or more source files and choose an output format to merge."
                : "Enter an output format such as \(Self.supportedFormatSummary)."
        case let .invalidFormat(input):
            let normalized = FormatRegistry.normalizedKey(for: input)
            statusMessage = normalized.isEmpty
                ? "Enter an output format such as \(Self.supportedFormatSummary)."
                : "\"\(normalized)\" is not supported. Try \(Self.supportedFormatSummary)."
        case let .valid(format):
            if selectedFiles.isEmpty {
                statusMessage = "Bundled ffmpeg is ready. Select two or more source files to merge into one \(format.displayName) file."
            } else if selectedFiles.count == 1 {
                statusMessage = "Add at least one more source file to merge into one \(format.displayName) file."
            } else if let mergeDestinationURL {
                statusMessage = "Ready to merge \(selectedFiles.count) file(s) into \(mergeDestinationURL.lastPathComponent)."
            } else {
                statusMessage = "Choose a destination for the merged \(format.displayName) file."
            }
        }
    }

    private static func restorePreferredFormat(from preferencesStore: UserDefaults) -> String {
        let storedFormat = preferencesStore.string(forKey: preferredFormatDefaultsKey) ?? "mp3"
        return storedFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mp3" : storedFormat
    }

    private static func restorePreferredOperationMode(from preferencesStore: UserDefaults) -> OperationMode {
        guard
            let storedValue = preferencesStore.string(forKey: preferredOperationModeDefaultsKey),
            let mode = OperationMode(rawValue: storedValue)
        else {
            return .batchConvert
        }

        return mode
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

    private func makeMergeCompletionStatusMessage(for snapshots: [BatchStatusSnapshot], format: SupportedFormat) -> String {
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

    private func makeMergeInFlightStatusMessage(for snapshots: [BatchStatusSnapshot], format: SupportedFormat) -> String {
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
