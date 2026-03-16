import Foundation
import SwiftUI

@main
struct AudioConverterApp: App {
    @StateObject private var appState: AppState

    init() {
        _appState = StateObject(wrappedValue: Self.makeAppState())
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 720, minHeight: 480)
                .task {
                    appState.performStartupChecksIfNeeded()
                }
        }
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
        let conversionScenario = UITestConversionScenario(
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

        if processInfo.arguments.contains(UITestConversionScenario.launchArgument),
           conversionScenario == nil {
            fatalError(
                "Invalid UI test conversion scenario. Set \(UITestConversionScenario.environmentKey) to \(UITestConversionScenario.supportedValuesDescription)."
            )
        }

        guard startupScenario != nil || fileSelectionScenario != nil || conversionScenario != nil else {
            return AppState()
        }

        let selectAudioFiles = fileSelectionScenario?.makeFileSelector() ?? {
            OpenPanelPresenter().selectFiles()
        }
        let makeConversionSession = conversionScenario?.makeConversionSessionFactory()

        if let startupScenario {
            return startupScenario.makeAppState(
                selectAudioFiles: selectAudioFiles,
                makeConversionSession: makeConversionSession
            )
        }

        if let makeConversionSession {
            return AppState(
                selectAudioFiles: selectAudioFiles,
                makeConversionSession: makeConversionSession
            )
        }

        return AppState(selectAudioFiles: selectAudioFiles)
#else
        return AppState()
#endif
    }
}

private final class UITestStartupScenario {
    private enum Mode {
        case failThenSuccess
        case alwaysFail
    }

    static let environmentKey = "AUDIOCONVERTER_UI_TEST_STARTUP_SCENARIO"
    static let launchArgument = "--uitest-startup-scenario"
    static let supportedValuesDescription = "[fail-then-success | always-fail]"
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
        makeConversionSession: AppState.ConversionSessionFactory? = nil
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

        return AppState(
            resolveFFmpegURL: { .ready(ffmpegURL) },
            validateStartupCapabilities: { [self] _ in nextValidationResult() },
            selectAudioFiles: selectAudioFiles,
            makeConversionSession: conversionSessionFactory
        )
    }

    private func nextValidationResult() -> StartupState {
        lock.lock()
        defer { lock.unlock() }

        validationAttempts += 1

        switch mode {
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
        items = files.map { Item(id: UUID(), file: $0, state: .queued) }
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
            delay += 0.35

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
            delay += 0.35
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
            BatchStatusSnapshot(id: item.id, fileName: item.file.displayName, state: item.state)
        }
    }

    private func makeOutputURL(for file: SelectedAudioFile) -> URL {
        file.directoryURL.appendingPathComponent(
            file.url.deletingPathExtension().lastPathComponent + "." + format.outputExtension
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
