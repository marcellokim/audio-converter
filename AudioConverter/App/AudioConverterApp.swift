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

        guard startupScenario != nil || fileSelectionScenario != nil else {
            return AppState()
        }

        let selectAudioFiles = fileSelectionScenario?.makeFileSelector() ?? {
            OpenPanelPresenter().selectFiles()
        }

        if let startupScenario {
            return startupScenario.makeAppState(selectAudioFiles: selectAudioFiles)
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

    func makeAppState(selectAudioFiles: @escaping AppState.FileSelector = { OpenPanelPresenter().selectFiles() }) -> AppState {
        let fallbackURL = URL(fileURLWithPath: "/bin/sh")
        let ffmpegURL = FFmpegBinaryResolver.bundledBinaryURL() ?? fallbackURL

        return AppState(
            resolveFFmpegURL: { .ready(ffmpegURL) },
            validateStartupCapabilities: { [self] _ in nextValidationResult() },
            selectAudioFiles: selectAudioFiles
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
