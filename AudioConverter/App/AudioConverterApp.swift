import Foundation
import SwiftUI

@main
struct AudioConverterApp: App {
    @StateObject private var appState: AppState

    init() {
        let processInfo = ProcessInfo.processInfo
        _appState = StateObject(wrappedValue: Self.makeAppState(processInfo: processInfo))
        initialWindowSize = Self.makeInitialWindowSize(processInfo: processInfo)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 820)
                .task {
                    appState.performStartupChecksIfNeeded()
                }
        }
        .defaultSize(width: 960, height: 920)
        .windowResizability(.contentSize)
    }

    private static func makeAppState(processInfo: ProcessInfo = .processInfo) -> AppState {
#if DEBUG
        let startupScenario = UITestStartupScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )
        let fileSelectionScenario = UITestFileSelectionScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )
        let savePanelScenario = UITestSavePanelScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )
        let conversionScenario = UITestConversionScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )
        let mergeScenario = UITestMergeScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )

        if processInfo.arguments.contains(UITestStartupScenario.launchArgument),
           startupScenario == nil {
            fatalError(
                "Invalid UI test startup scenario. Set \(UITestStartupScenario.environmentKey) to \(UITestStartupScenario.supportedValuesDescription)."
            )
        }

        if processInfo.arguments.contains(UITestFileSelectionScenario.launchArgument),
           fileSelectionScenario == nil {
            fatalError(
                "Invalid UI test file-selection scenario. Set \(UITestFileSelectionScenario.environmentKey) to a comma-separated list using \(UITestFileSelectionScenario.supportedValuesDescription)."
            )
        }

        if processInfo.arguments.contains(UITestSavePanelScenario.launchArgument),
           savePanelScenario == nil {
            fatalError(
                "Invalid UI test save-panel scenario. Set \(UITestSavePanelScenario.environmentKey) to \(UITestSavePanelScenario.supportedValuesDescription)."
            )
        }

        if processInfo.arguments.contains(UITestConversionScenario.launchArgument),
           conversionScenario == nil {
            fatalError(
                "Invalid UI test conversion scenario. Set \(UITestConversionScenario.environmentKey) to \(UITestConversionScenario.supportedValuesDescription)."
            )
        }

        if processInfo.arguments.contains(UITestMergeScenario.launchArgument),
           mergeScenario == nil {
            fatalError(
                "Invalid UI test merge scenario. Set \(UITestMergeScenario.environmentKey) to \(UITestMergeScenario.supportedValuesDescription)."
            )
        }

        guard startupScenario != nil || fileSelectionScenario != nil || savePanelScenario != nil || conversionScenario != nil || mergeScenario != nil else {
            return AppState()
        }

        let selectAudioFiles = fileSelectionScenario?.makeFileSelector() ?? {
            OpenPanelPresenter().selectFiles()
        }
        let selectMergeDestinationURL = savePanelScenario?.makeMergeDestinationSelector() ?? { files, format in
            SavePanelPresenter().chooseDestination(
                for: format,
                suggestedBaseName: files.first?.url.deletingPathExtension().lastPathComponent ?? "merged-audio"
            )
        }
        let makeConversionSession = conversionScenario?.makeConversionSessionFactory()
        let makeMergeSession = mergeScenario?.makeMergeSessionFactory()

        if let startupScenario {
            return startupScenario.makeAppState(
                selectAudioFiles: selectAudioFiles,
                selectMergeDestinationURL: selectMergeDestinationURL,
                makeConversionSession: makeConversionSession,
                makeMergeSession: makeMergeSession
            )
        }

        if makeConversionSession != nil || makeMergeSession != nil || savePanelScenario != nil {
            return AppState(
                selectAudioFiles: selectAudioFiles,
                selectMergeDestinationURL: selectMergeDestinationURL,
                makeConversionSession: makeConversionSession ?? { files, format, ffmpegURL, onUpdate, onCompletion in
                    ConversionCoordinator().makeSession(
                        files: files,
                        format: format,
                        ffmpegURL: ffmpegURL,
                        onUpdate: onUpdate,
                        onCompletion: onCompletion
                    )
                },
                makeMergeSession: makeMergeSession ?? { files, format, destinationURL, ffmpegURL, onUpdate, onCompletion in
                    MergeExportCoordinator().makeSession(
                        files: files,
                        format: format,
                        destinationURL: destinationURL,
                        ffmpegURL: ffmpegURL,
                        onUpdate: onUpdate,
                        onCompletion: onCompletion
                    )
                }
            )
        }

        return AppState(
            selectAudioFiles: selectAudioFiles,
            selectMergeDestinationURL: selectMergeDestinationURL
        )
#else
        return AppState()
#endif
    }
}

private final class UITestStartupScenario {
    private enum Mode {
        case alwaysReady
        case failThenSuccess
        case alwaysFail
    }

    static let environmentKey = "AUDIOCONVERTER_UI_TEST_STARTUP_SCENARIO"
    static let launchArgument = "--uitest-startup-scenario"
    static let supportedValuesDescription = "[always-ready | fail-then-success | always-fail]"
    private static let simulatedFailureMessage = "Simulated startup check failure. Retry to continue."

    private let mode: Mode
    private let lock = NSLock()
    private var validationAttempts = 0

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(Self.launchArgument),
              let rawValue = environment[Self.environmentKey] else {
            return nil
        }

        switch rawValue {
        case "always-ready":
            mode = .alwaysReady
        case "fail-then-success":
            mode = .failThenSuccess
        case "always-fail":
            mode = .alwaysFail
        default:
            return nil
        }
    }

    func makeAppState(
        selectAudioFiles: @escaping AppState.FileSelector = { OpenPanelPresenter().selectFiles() },
        selectMergeDestinationURL: @escaping AppState.MergeDestinationSelector = { files, format in
            SavePanelPresenter().chooseDestination(
                for: format,
                suggestedBaseName: files.first?.url.deletingPathExtension().lastPathComponent ?? "merged-audio"
            )
        },
        makeConversionSession: AppState.ConversionSessionFactory? = nil,
        makeMergeSession: AppState.MergeSessionFactory? = nil
    ) -> AppState {
        let fallbackURL = URL(fileURLWithPath: "/bin/sh")
        let ffmpegURL = FFmpegBinaryResolver.bundledBinaryURL() ?? fallbackURL
        let conversionSessionFactory = makeConversionSession ?? { files, format, ffmpegURL, onUpdate, onCompletion in
            ConversionCoordinator().makeSession(
                files: files,
                format: format,
                ffmpegURL: ffmpegURL,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }
        let mergeSessionFactory = makeMergeSession ?? { files, format, destinationURL, ffmpegURL, onUpdate, onCompletion in
            MergeExportCoordinator().makeSession(
                files: files,
                format: format,
                destinationURL: destinationURL,
                ffmpegURL: ffmpegURL,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }

        return AppState(
            resolveFFmpegURL: { .ready(ffmpegURL) },
            validateStartupCapabilities: { [self] _ in nextValidationResult() },
            selectAudioFiles: selectAudioFiles,
            selectMergeDestinationURL: selectMergeDestinationURL,
            makeConversionSession: conversionSessionFactory,
            makeMergeSession: mergeSessionFactory
        )
    }

    private func nextValidationResult() -> StartupState {
        lock.lock()
        defer { lock.unlock() }

        validationAttempts += 1

        switch mode {
        case .alwaysReady:
            return .ready
        case .failThenSuccess:
            return validationAttempts == 1
                ? .startupError(Self.simulatedFailureMessage)
                : .ready
        case .alwaysFail:
            return .startupError(Self.simulatedFailureMessage)
        }
    }
}

private enum UITestConversionMode {
    case completeSuccess
    case cancelAfterStart
}

private final class UITestConversionScenario {

    static let environmentKey = "AUDIOCONVERTER_UI_TEST_CONVERSION_SCENARIO"
    static let launchArgument = "--uitest-conversion-scenario"
    static let supportedValuesDescription = "[complete-success | cancel-after-start]"

    private let mode: UITestConversionMode

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(Self.launchArgument),
              let rawValue = environment[Self.environmentKey] else {
            return nil
        }

        switch rawValue {
        case "complete-success":
            mode = .completeSuccess
        case "cancel-after-start":
            mode = .cancelAfterStart
        default:
            return nil
        }
    }

    func makeConversionSessionFactory() -> AppState.ConversionSessionFactory {
        { [mode] files, format, _, onUpdate, onCompletion in
            UITestConversionSession(
                files: files,
                format: format,
                mode: mode,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }
    }
}

private final class UITestConversionSession: BatchConversionSessioning {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private struct Item {
        let id: UUID
        let file: SelectedAudioFile
        var state: ConversionItemState
        var fractionCompleted: Double?
        var isIndeterminate: Bool
        var progressDetail: String?
    }

    private let format: SupportedFormat
    private let mode: UITestConversionMode
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let files: [SelectedAudioFile]
    private let lock = NSLock()

    private var items: [Item]
    private var scheduledWorkItems: [DispatchWorkItem] = []
    private var hasStarted = false
    private var hasCompleted = false
    private var cancellationRequested = false

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        mode: UITestConversionMode,
        onUpdate: @escaping SnapshotHandler,
        onCompletion: @escaping SnapshotHandler
    ) {
        self.format = format
        self.mode = mode
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
        self.files = files
        items = files.map {
            Item(
                id: UUID(),
                file: $0,
                state: .queued,
                fractionCompleted: nil,
                isIndeterminate: false,
                progressDetail: nil
            )
        }
    }

    func start() {
        let initialSnapshots: [BatchStatusSnapshot]

        lock.lock()
        guard !hasStarted else {
            lock.unlock()
            return
        }
        hasStarted = true
        initialSnapshots = snapshotsLocked()
        lock.unlock()

        onUpdate(initialSnapshots)
        scheduleScenario()
    }

    func cancelAll() {
        let snapshotsToPublish: [BatchStatusSnapshot]
        let workItemsToCancel: [DispatchWorkItem]

        lock.lock()
        guard hasStarted, !hasCompleted, !cancellationRequested else {
            lock.unlock()
            return
        }

        cancellationRequested = true
        items = items.map { item in
            var updated = item
            switch updated.state {
            case .queued, .running:
                updated.state = .cancelled
                updated.fractionCompleted = nil
                updated.isIndeterminate = false
                updated.progressDetail = nil
            case .succeeded, .failed, .skipped, .cancelled:
                break
            }
            return updated
        }
        workItemsToCancel = scheduledWorkItems
        scheduledWorkItems.removeAll()
        snapshotsToPublish = snapshotsLocked()
        hasCompleted = true
        lock.unlock()

        workItemsToCancel.forEach { $0.cancel() }
        onUpdate(snapshotsToPublish)
        onCompletion(snapshotsToPublish)
    }

    private func scheduleScenario() {
        switch mode {
        case .completeSuccess:
            scheduleSuccessfulCompletionScenario()
        case .cancelAfterStart:
            scheduleCancelableScenario()
        }
    }

    private func scheduleSuccessfulCompletionScenario() {
        guard !files.isEmpty else {
            finishIfNeeded()
            return
        }

        var delay: TimeInterval = 0.20

        for (index, file) in files.enumerated() {
            schedule(after: delay) { [weak self] in
                self?.publish(state: .running, for: index)
            }
            delay += 0.20

            schedule(after: delay) { [weak self] in
                self?.publishProgress(
                    fractionCompleted: 0.25,
                    detail: "25% complete",
                    for: index
                )
            }
            delay += 0.40

            schedule(after: delay) { [weak self] in
                self?.publishProgress(
                    fractionCompleted: 0.75,
                    detail: "75% complete",
                    for: index
                )
            }
            delay += 0.60

            schedule(after: delay) { [weak self] in
                guard let self else {
                    return
                }

                let outputURL = self.makeOutputURL(for: file)
                self.publish(state: .succeeded(outputURL: outputURL), for: index)

                if index == self.files.indices.last {
                    self.finishIfNeeded()
                }
            }
            delay += 0.20
        }
    }

    private func scheduleCancelableScenario() {
        guard !files.isEmpty else {
            finishIfNeeded()
            return
        }

        schedule(after: 0.20) { [weak self] in
            self?.publish(state: .running, for: 0)
        }
    }

    private func publish(state: ConversionItemState, for index: Int) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard items.indices.contains(index), !hasCompleted else {
            lock.unlock()
            return
        }
        items[index].state = state
        switch state {
        case .running:
            items[index].fractionCompleted = nil
            items[index].isIndeterminate = true
            items[index].progressDetail = nil
        case .queued:
            items[index].fractionCompleted = nil
            items[index].isIndeterminate = false
            items[index].progressDetail = nil
        case .succeeded, .failed, .skipped, .cancelled:
            items[index].fractionCompleted = nil
            items[index].isIndeterminate = false
            items[index].progressDetail = nil
        }
        snapshotsToPublish = snapshotsLocked()
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func publishProgress(fractionCompleted: Double?, detail: String, for index: Int) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard items.indices.contains(index), !hasCompleted else {
            lock.unlock()
            return
        }

        items[index].state = .running
        items[index].fractionCompleted = fractionCompleted
        items[index].isIndeterminate = fractionCompleted == nil
        items[index].progressDetail = detail
        snapshotsToPublish = snapshotsLocked()
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isCancellationRequested else {
                return
            }
            action()
        }

        lock.lock()
        scheduledWorkItems.append(workItem)
        lock.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func finishIfNeeded() {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted else {
            lock.unlock()
            return
        }
        hasCompleted = true
        snapshotsToPublish = snapshotsLocked()
        lock.unlock()

        onCompletion(snapshotsToPublish)
    }

    private var isCancellationRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private func snapshotsLocked() -> [BatchStatusSnapshot] {
        items.map { item in
            BatchStatusSnapshot(
                id: item.id,
                fileName: item.file.displayName,
                state: item.state,
                fractionCompleted: item.state == .running ? item.fractionCompleted : nil,
                isIndeterminate: item.state == .running ? item.isIndeterminate : false,
                progressDetail: item.state == .running ? item.progressDetail : nil
            )
        }
    }

    private func makeOutputURL(for file: SelectedAudioFile) -> URL {
        file.directoryURL.appendingPathComponent(
            file.url.deletingPathExtension().lastPathComponent + "." + format.outputExtension
        )
    }
}

private final class UITestSavePanelScenario {
    private enum Mode {
        case chooseDestination
        case cancel
    }

    static let environmentKey = "AUDIOCONVERTER_UI_TEST_SAVE_PANEL_SCENARIO"
    static let launchArgument = "--uitest-save-panel-scenario"
    static let supportedValuesDescription = "[choose-destination | cancel]"

    private let mode: Mode

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(Self.launchArgument),
              let rawValue = environment[Self.environmentKey] else {
            return nil
        }

        switch rawValue {
        case "choose-destination":
            mode = .chooseDestination
        case "cancel":
            mode = .cancel
        default:
            return nil
        }
    }

    func makeMergeDestinationSelector() -> AppState.MergeDestinationSelector {
        { [mode] files, format in
            switch mode {
            case .cancel:
                return nil
            case .chooseDestination:
                let suggestedBaseName = files.first?.url.deletingPathExtension().lastPathComponent ?? "merged-audio"
                return URL(fileURLWithPath: "/tmp/\(suggestedBaseName)-merged.\(format.outputExtension)")
            }
        }
    }
}

private enum UITestMergeMode {
    case completeSuccess
    case cancelAfterStart
}

private final class UITestMergeScenario {
    static let environmentKey = "AUDIOCONVERTER_UI_TEST_MERGE_SCENARIO"
    static let launchArgument = "--uitest-merge-scenario"
    static let supportedValuesDescription = "[complete-success | cancel-after-start]"

    private let mode: UITestMergeMode

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(Self.launchArgument),
              let rawValue = environment[Self.environmentKey] else {
            return nil
        }

        switch rawValue {
        case "complete-success":
            mode = .completeSuccess
        case "cancel-after-start":
            mode = .cancelAfterStart
        default:
            return nil
        }
    }

    func makeMergeSessionFactory() -> AppState.MergeSessionFactory {
        { [mode] files, format, destinationURL, _, onUpdate, onCompletion in
            UITestMergeSession(
                files: files,
                format: format,
                destinationURL: destinationURL,
                mode: mode,
                onUpdate: onUpdate,
                onCompletion: onCompletion
            )
        }
    }
}

private final class UITestMergeSession: BatchConversionSessioning {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private let files: [SelectedAudioFile]
    private let format: SupportedFormat
    private let destinationURL: URL
    private let mode: UITestMergeMode
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let lock = NSLock()
    private let snapshotID = UUID()

    private var state: ConversionItemState = .queued
    private var fractionCompleted: Double?
    private var progressDetail: String?
    private var hasStarted = false
    private var hasCompleted = false
    private var cancellationRequested = false
    private var scheduledWorkItems: [DispatchWorkItem] = []

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        destinationURL: URL,
        mode: UITestMergeMode,
        onUpdate: @escaping SnapshotHandler,
        onCompletion: @escaping SnapshotHandler
    ) {
        self.files = files
        self.format = format
        self.destinationURL = destinationURL
        self.mode = mode
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
    }

    func start() {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasStarted else {
            lock.unlock()
            return
        }
        hasStarted = true
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(snapshotsToPublish)
        scheduleScenario()
    }

    func cancelAll() {
        let snapshotsToPublish: [BatchStatusSnapshot]
        let workItemsToCancel: [DispatchWorkItem]

        lock.lock()
        guard hasStarted, !hasCompleted, !cancellationRequested else {
            lock.unlock()
            return
        }

        cancellationRequested = true
        state = .cancelled
        fractionCompleted = nil
        progressDetail = nil
        workItemsToCancel = scheduledWorkItems
        scheduledWorkItems.removeAll()
        snapshotsToPublish = [makeSnapshotLocked()]
        hasCompleted = true
        lock.unlock()

        workItemsToCancel.forEach { $0.cancel() }
        onUpdate(snapshotsToPublish)
        onCompletion(snapshotsToPublish)
    }

    private func scheduleScenario() {
        guard files.count >= 2 else {
            publishTerminalState(.failed(reason: .validation("Select at least two source audio files before merging.")))
            return
        }

        switch mode {
        case .completeSuccess:
            schedule(after: 0.20) { [weak self] in
                self?.publishRunningState(fractionCompleted: 0.25, progressDetail: "25% merged")
            }
            schedule(after: 0.60) { [weak self] in
                self?.publishRunningState(fractionCompleted: 0.80, progressDetail: "80% merged")
            }
            schedule(after: 0.90) { [weak self] in
                self?.publishTerminalState(.succeeded(outputURL: self?.destinationURL ?? URL(fileURLWithPath: "/tmp/merged-output.tmp")))
            }
        case .cancelAfterStart:
            schedule(after: 0.20) { [weak self] in
                self?.publishRunningState(fractionCompleted: nil, progressDetail: "Merging with ffmpeg.")
            }
        }
    }

    private func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isCancellationRequested else {
                return
            }
            action()
        }

        lock.lock()
        scheduledWorkItems.append(workItem)
        lock.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func publishRunningState(fractionCompleted: Double?, progressDetail: String) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted else {
            lock.unlock()
            return
        }
        state = .running
        self.fractionCompleted = fractionCompleted
        self.progressDetail = progressDetail
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func publishTerminalState(_ terminalState: ConversionItemState) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted else {
            lock.unlock()
            return
        }
        hasCompleted = true
        state = terminalState
        fractionCompleted = nil
        progressDetail = nil
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(snapshotsToPublish)
        onCompletion(snapshotsToPublish)
    }

    private var isCancellationRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private func makeSnapshotLocked() -> BatchStatusSnapshot {
        BatchStatusSnapshot(
            id: snapshotID,
            fileName: destinationURL.lastPathComponent,
            state: state,
            fractionCompleted: state == .running ? fractionCompleted : nil,
            isIndeterminate: state == .running ? fractionCompleted == nil : false,
            progressDetail: state == .running ? progressDetail : nil
        )
    }
}

private final class UITestFileSelectionScenario {
    private enum Step {
        case cancel
        case selected([SelectedAudioFile])
    }

    static let environmentKey = "AUDIOCONVERTER_UI_TEST_FILE_SELECTION_SCENARIO"
    static let launchArgument = "--uitest-file-selection-scenario"
    static let supportedValuesDescription = "[single | multiple | cancel]"

    private let lock = NSLock()
    private var steps: [Step]

    init?(arguments: [String], environment: [String: String]) {
        guard arguments.contains(Self.launchArgument),
              let rawValue = environment[Self.environmentKey] else {
            return nil
        }

        let tokens = rawValue.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let parsedSteps = tokens.compactMap(Self.parseStep)

        guard !tokens.isEmpty, parsedSteps.count == tokens.count else {
            return nil
        }

        steps = parsedSteps
    }

    func makeFileSelector() -> AppState.FileSelector {
        { [self] in
            nextSelectionResult()
        }
    }

    private func nextSelectionResult() -> [SelectedAudioFile] {
        lock.lock()
        defer { lock.unlock() }

        let nextStep = steps.isEmpty ? .cancel : steps.removeFirst()
        switch nextStep {
        case .cancel:
            return []
        case let .selected(files):
            return files
        }
    }

    private static func parseStep(_ token: String) -> Step? {
        switch token {
        case "cancel":
            return .cancel
        case "single":
            return .selected([
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/ui-test-source-1.wav"))
            ])
        case "multiple":
            return .selected([
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/ui-test-source-1.wav")),
                SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/ui-test-source-2.aiff"))
            ])
        default:
            return nil
        }
    }
}
