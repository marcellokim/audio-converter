import Foundation

protocol BatchConversionSessioning: AnyObject {
    func start()
    func cancelAll()
}

extension ConversionCoordinatorSession: BatchConversionSessioning {}
final class AppState: ObservableObject {
    private static let preferredFormatDefaultsKey = "AudioConverter.preferredFormat"
    private static let preferredOperationModeDefaultsKey = "AudioConverter.preferredOperationMode"
    private static let selectedFilesDefaultsKey = "AudioConverter.selectedFiles"
    private static let mergeDestinationURLDefaultsKey = "AudioConverter.mergeDestinationURL"
    private static let schedulerUsesAutomaticConcurrencyDefaultsKey = "AudioConverter.scheduler.usesAutomaticConcurrency"
    private static let schedulerManualConcurrentJobLimitDefaultsKey = "AudioConverter.scheduler.manualConcurrentJobLimit"

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
        Int,
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
            persistSelectedFiles()
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
    @Published private(set) var mergeDestinationURL: URL? {
        didSet {
            persistMergeDestinationURL()
        }
    }
    @Published private(set) var schedulerSettings = QueueSchedulerSettings() {
        didSet {
            persistSchedulerSettings()
        }
    }

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
        preferencesStore: UserDefaults = AppState.makeTransientPreferencesStore(),
        makeConversionSession: @escaping ConversionSessionFactory = { files, format, ffmpegURL, maximumConcurrentJobs, onUpdate, onCompletion in
            ConversionCoordinator(maximumConcurrentJobs: maximumConcurrentJobs).makeSession(
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
        self.selectedFiles = Self.restoreSelectedFiles(from: preferencesStore)
        self.mergeDestinationURL = Self.restoreMergeDestinationURL(from: preferencesStore)
        self.schedulerSettings = Self.restoreSchedulerSettings(from: preferencesStore)
    }

    var selectedAudioFiles: [SelectedAudioFile] {
        selectedFiles.map(SelectedAudioFile.init)
    }

    var queueDashboardSnapshot: QueueDashboardSnapshot {
        QueueDashboardSnapshot(
            snapshots: batchSnapshots,
            stagedFileCount: selectedFiles.count,
            operationMode: operationMode,
            schedulerSettings: schedulerSettings
        )
    }

    var effectiveConcurrentJobLimit: Int {
        operationMode == .mergeIntoOne
            ? 1
            : schedulerSettings.effectiveConcurrentJobLimit
    }

    var manualConcurrentJobLimit: Int {
        schedulerSettings.manualConcurrentJobLimit
    }

    var formatValidationState: ValidationState {
        let trimmed = outputFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .idle
        }

        return FormatValidator.validate(outputFormat: trimmed)
    }

    var canOpenFiles: Bool {
        AppStateWorkflowRules.canOpenFiles(
            startupState: startupState,
            isConverting: isConverting
        )
    }

    var canRemoveSelectedFiles: Bool {
        AppStateWorkflowRules.canRemoveSelectedFiles(
            isConverting: isConverting,
            selectedFileCount: selectedFiles.count
        )
    }

    var canRetryStartupChecks: Bool {
        AppStateWorkflowRules.canRetryStartupChecks(startupState: startupState)
    }

    var canStartConversion: Bool {
        AppStateWorkflowRules.canStartConversion(
            operationMode: operationMode,
            startupState: startupState,
            isConverting: isConverting,
            selectedFileCount: selectedFiles.count,
            validationState: formatValidationState
        )
    }

    var canChooseMergeDestination: Bool {
        AppStateWorkflowRules.canChooseMergeDestination(
            operationMode: operationMode,
            startupState: startupState,
            isConverting: isConverting,
            selectedFileCount: selectedFiles.count,
            validationState: formatValidationState
        )
    }

    var canStartMerge: Bool {
        AppStateWorkflowRules.canStartMerge(
            operationMode: operationMode,
            startupState: startupState,
            isConverting: isConverting,
            selectedFileCount: selectedFiles.count,
            validationState: formatValidationState,
            hasMergeDestination: mergeDestinationURL != nil
        )
    }

    var canCancelConversion: Bool {
        AppStateWorkflowRules.canCancelConversion(
            isConverting: isConverting,
            isCancelling: isCancelling,
            hasCurrentSession: currentSession != nil
        )
    }

    var canReorderSelectedFiles: Bool {
        AppStateWorkflowRules.canReorderSelectedFiles(
            operationMode: operationMode,
            isConverting: isConverting,
            selectedFileCount: selectedFiles.count
        )
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
            statusMessage = AppStateStatusPolicy.selectionCancelledMessage(
                existingFileCount: selectedFiles.count
            )
            return
        }

        clearBatchSnapshotsForSelectionMutation()
        selectedFiles = files.map(\.url)
        statusMessage = AppStateStatusPolicy.loadedFilesMessage(
            fileCount: files.count,
            operationMode: operationMode
        )
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

        guard let format = validatedFormatOrUpdateStatusMessage() else {
            return
        }

        let destinationURL = selectMergeDestinationURL(files, format)
        guard let destinationURL else {
            statusMessage = AppStateStatusPolicy.mergeDestinationSelectionCancelledMessage(
                currentDestinationURL: mergeDestinationURL
            )
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

    func setAutomaticSchedulingEnabled(_ isEnabled: Bool) {
        guard !isConverting else {
            return
        }

        schedulerSettings.usesAutomaticConcurrency = isEnabled
        refreshStatusMessageForCurrentInputs()
    }

    func updateManualConcurrentJobLimit(_ value: Int) {
        guard !isConverting else {
            return
        }

        schedulerSettings.updateManualConcurrentJobLimit(value)
        refreshStatusMessageForCurrentInputs()
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

        guard let format = validatedFormatOrUpdateStatusMessage() else {
            return
        }

        isConverting = true
        isCancelling = false
        statusMessage = AppStateStatusPolicy.conversionStartedMessage(
            fileCount: files.count,
            format: format
        )
        batchSnapshots = []

        let session = makeConversionSession(
            files,
            format,
            ffmpegURL,
            effectiveConcurrentJobLimit,
            { [weak self] snapshots in
                self?.performOnMain {
                    guard let self else {
                        return
                    }

                    self.batchSnapshots = snapshots
                    if self.isConverting {
                        self.statusMessage = self.isCancelling
                            ? "Cancelling current batch…"
                            : AppStateStatusPolicy.conversionInFlightMessage(
                                snapshots: snapshots,
                                format: format
                            )
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
                    self.statusMessage = AppStateStatusPolicy.conversionCompletionMessage(
                        snapshots: snapshots,
                        format: format
                    )
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

        guard let format = validatedFormatOrUpdateStatusMessage() else {
            return
        }

        guard let mergeDestinationURL else {
            statusMessage = "Choose a destination for the merged \(format.displayName) file."
            return
        }

        isConverting = true
        isCancelling = false
        statusMessage = AppStateStatusPolicy.mergeStartedMessage(
            fileCount: files.count,
            destinationURL: mergeDestinationURL
        )
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
                            : AppStateStatusPolicy.mergeInFlightMessage(
                                snapshots: snapshots,
                                format: format
                            )
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
                    self.statusMessage = AppStateStatusPolicy.mergeCompletionMessage(
                        snapshots: snapshots,
                        format: format
                    )
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

        statusMessage = AppStateStatusPolicy.currentInputMessage(
            startupState: startupState,
            operationMode: operationMode,
            selectedFileCount: selectedFiles.count,
            validationState: formatValidationState,
            mergeDestinationURL: mergeDestinationURL,
            supportedFormatSummary: Self.supportedFormatSummary
        )
    }

    private static func makeTransientPreferencesStore() -> UserDefaults {
        let suiteName = "AudioConverter.AppState.Transient.\(UUID().uuidString)"
        guard let store = UserDefaults(suiteName: suiteName) else {
            return .standard
        }

        store.removePersistentDomain(forName: suiteName)
        return store
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

    private static func restoreSelectedFiles(from preferencesStore: UserDefaults) -> [URL] {
        preferencesStore.stringArray(forKey: selectedFilesDefaultsKey)?
            .map { URL(fileURLWithPath: $0) } ?? []
    }

    private static func restoreMergeDestinationURL(from preferencesStore: UserDefaults) -> URL? {
        guard let path = preferencesStore.string(forKey: mergeDestinationURLDefaultsKey),
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    private static func restoreSchedulerSettings(from preferencesStore: UserDefaults) -> QueueSchedulerSettings {
        let usesAutomaticConcurrency = preferencesStore.object(forKey: schedulerUsesAutomaticConcurrencyDefaultsKey) == nil
            ? true
            : preferencesStore.bool(forKey: schedulerUsesAutomaticConcurrencyDefaultsKey)
        let manualLimit = preferencesStore.object(forKey: schedulerManualConcurrentJobLimitDefaultsKey) == nil
            ? 2
            : preferencesStore.integer(forKey: schedulerManualConcurrentJobLimitDefaultsKey)
        return QueueSchedulerSettings(
            usesAutomaticConcurrency: usesAutomaticConcurrency,
            manualConcurrentJobLimit: manualLimit
        )
    }

    private func persistSelectedFiles() {
        preferencesStore.set(selectedFiles.map(\.path), forKey: Self.selectedFilesDefaultsKey)
    }

    private func persistMergeDestinationURL() {
        if let mergeDestinationURL {
            preferencesStore.set(mergeDestinationURL.path, forKey: Self.mergeDestinationURLDefaultsKey)
        } else {
            preferencesStore.removeObject(forKey: Self.mergeDestinationURLDefaultsKey)
        }
    }

    private func persistSchedulerSettings() {
        preferencesStore.set(
            schedulerSettings.usesAutomaticConcurrency,
            forKey: Self.schedulerUsesAutomaticConcurrencyDefaultsKey
        )
        preferencesStore.set(
            schedulerSettings.manualConcurrentJobLimit,
            forKey: Self.schedulerManualConcurrentJobLimitDefaultsKey
        )
    }

    private func validatedFormatOrUpdateStatusMessage() -> SupportedFormat? {
        switch formatValidationState {
        case let .valid(format):
            return format
        case .idle, .invalidFormat:
            statusMessage = AppStateStatusPolicy.formatRequirementMessage(
                for: formatValidationState,
                supportedFormatSummary: Self.supportedFormatSummary
            )
            return nil
        }
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
