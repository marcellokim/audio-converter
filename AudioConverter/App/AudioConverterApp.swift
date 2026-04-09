import Foundation
import SwiftUI

@main
struct AudioConverterApp: App {
    @StateObject private var appState: AppState
    private let initialWindowSize: CGSize

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
        .defaultSize(width: initialWindowSize.width, height: initialWindowSize.height)
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
            return AppState(preferencesStore: .standard)
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
        return AppState(preferencesStore: .standard)
#endif
    }

    private static func makeInitialWindowSize(processInfo: ProcessInfo = .processInfo) -> CGSize {
#if DEBUG
        let windowSize = UITestWindowSize(
            arguments: processInfo.arguments,
            environment: processInfo.environment
        )

        if processInfo.arguments.contains(UITestWindowSize.launchArgument),
           windowSize == nil {
            fatalError(
                "Invalid UI test window size. Set \(UITestWindowSize.widthEnvironmentKey) and \(UITestWindowSize.heightEnvironmentKey) to numeric values that satisfy \(UITestWindowSize.supportedValuesDescription)."
            )
        }

        if let windowSize {
            return windowSize.size
        }
#endif

        return CGSize(width: 960, height: 920)
    }
}
