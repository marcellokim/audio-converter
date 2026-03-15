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
        guard let startupScenario = UITestStartupScenario(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        ) else {
            return AppState()
        }

        return startupScenario.makeAppState()
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

    private static let environmentKey = "AUDIOCONVERTER_UI_TEST_STARTUP_SCENARIO"
    private static let launchArgument = "--uitest-startup-scenario"
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

    func makeAppState() -> AppState {
        let fallbackURL = URL(fileURLWithPath: "/bin/sh")
        let ffmpegURL = FFmpegBinaryResolver.bundledBinaryURL() ?? fallbackURL

        return AppState(
            resolveFFmpegURL: { .ready(ffmpegURL) },
            validateStartupCapabilities: { [self] _ in nextValidationResult() }
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
