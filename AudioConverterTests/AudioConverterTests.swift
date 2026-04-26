import Foundation
import AppKit
import SwiftUI
import XCTest
@testable import AudioConverter

final class AudioConverterTests: XCTestCase {
    func testAppStateStartsWithDefaultFormat() {
        let state = AppState()

        XCTAssertEqual(state.outputFormat, "mp3")
        XCTAssertFalse(state.canStartConversion)
    }

    func testMainViewLayoutUsesTwoZoneWorkspaceAtDefaultWindowWidth() {
        let layout = MainViewLayout(windowWidth: 960)

        XCTAssertEqual(layout.availableWidth, 928)
        XCTAssertTrue(layout.prefersTwoColumn)
    }

    func testMainViewLayoutCollapsesAtMinimumWindowWidth() {
        let layout = MainViewLayout(windowWidth: 720)

        XCTAssertEqual(layout.availableWidth, 688)
        XCTAssertFalse(layout.prefersTwoColumn)
    }

    @MainActor
    func testMainViewRendersInDefaultOneScreenCanvas() throws {
        let state = makeReadyAppState()
        try assertDefaultCanvasRender(
            state: state,
            artifactPath: "/tmp/audio-converter-layout-render.png"
        )
    }

    @MainActor
    func testMainViewMergeWorkspaceRendersInDefaultOneScreenCanvas() throws {
        let state = makeReadyAppState()
        state.operationMode = .mergeIntoOne
        state.selectedFiles = [
            URL(fileURLWithPath: "/tmp/ui-test-source-1.wav"),
            URL(fileURLWithPath: "/tmp/ui-test-source-2.aiff")
        ]

        try assertDefaultCanvasRender(
            state: state,
            artifactPath: "/tmp/audio-converter-layout-render-merge.png"
        )
    }

    func testCanStartConversionIsTrueWhenFilesExistAndFormatIsNotBlank() {
        let state = makeReadyAppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "flac"

        XCTAssertTrue(state.canStartConversion)
    }

    func testCanStartConversionIsFalseWhenFormatContainsOnlyWhitespace() {
        let state = AppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "   \n  "

        XCTAssertFalse(state.canStartConversion)
    }

    func testCanStartConversionIsFalseWhenStartupErrorExists() {
        let state = AppState()
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "aac"
        state.startupError = "Missing ffmpeg"

        XCTAssertFalse(state.canStartConversion)
    }

    func testCanStartConversionRecoversAfterStartupErrorClears() {
        var resolution: AppState.FFmpegResolution = .failure("Missing ffmpeg")
        let state = AppState(
            resolveFFmpegURL: { resolution },
            validateStartupCapabilities: { _ in .ready }
        )
        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "aac"

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Missing ffmpeg") = $0 {
                return true
            }

            return false
        }

        XCTAssertFalse(state.canStartConversion)

        resolution = .ready(URL(fileURLWithPath: "/bin/sh"))
        state.performStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }

        XCTAssertTrue(state.canStartConversion)
    }

    func testCanRetryStartupChecksIsOnlyAvailableAfterStartupFailure() {
        var validationResults: [StartupState] = [.startupError("Missing ffmpeg"), .ready]
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in validationResults.removeFirst() }
        )

        XCTAssertFalse(state.canRetryStartupChecks)

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Missing ffmpeg") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)

        state.retryStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }

        XCTAssertFalse(state.canRetryStartupChecks)
        XCTAssertNil(state.startupError)
    }

    func testRetryStartupChecksKeepsStartupBlockedWhenFailurePersists() {
        var attempts = 0
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in
                attempts += 1
                return .startupError("Startup failure attempt \(attempts)")
            }
        )

        state.performStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Startup failure attempt 1") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)
        XCTAssertFalse(state.canStartConversion)

        state.retryStartupChecks()
        waitForStartupState(of: state) {
            if case .startupError("Startup failure attempt 2") = $0 {
                return true
            }

            return false
        }

        XCTAssertTrue(state.canRetryStartupChecks)
        XCTAssertFalse(state.canOpenFiles)
        XCTAssertFalse(state.canStartConversion)
    }

    func testSelectFilesLoadsChosenFilesAndEnablesConversion() {
        let chosenFiles = [
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/voice-note.wav")),
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/session.aiff"))
        ]
        let state = makeReadyAppState(selectAudioFiles: { chosenFiles })

        state.selectFiles()

        XCTAssertEqual(state.selectedFiles, chosenFiles.map(\.url))
        XCTAssertEqual(state.statusMessage, "Ready to convert 2 file(s) to MP3.")
        XCTAssertTrue(state.canStartConversion)
    }

    func testSelectFilesReportsCancellationWhenPickerReturnsNoFiles() {
        let state = makeReadyAppState(selectAudioFiles: { [] })

        state.selectFiles()

        XCTAssertTrue(state.selectedFiles.isEmpty)
        XCTAssertEqual(state.statusMessage, "File selection cancelled.")
        XCTAssertFalse(state.canStartConversion)
    }

    func testSelectFilesCancellationKeepsExistingSelectionLoaded() {
        let chosenFiles = [
            SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/voice-note.wav"))
        ]
        var responses = [chosenFiles, []]
        let state = makeReadyAppState(selectAudioFiles: { responses.removeFirst() })

        state.selectFiles()
        state.selectFiles()

        XCTAssertEqual(state.selectedFiles, chosenFiles.map(\.url))
        XCTAssertEqual(state.statusMessage, "File selection cancelled. Keeping 1 loaded file(s).")
        XCTAssertTrue(state.canStartConversion)
    }

    func testRemoveSelectedFileRemovesOnlyThatFileAndClearsStaleSnapshots() {
        let session = ControlledConversionSession()
        let state = makeReadyAppState(session: session)
        let first = URL(fileURLWithPath: "/tmp/voice-note.wav")
        let second = URL(fileURLWithPath: "/tmp/session.aiff")
        state.selectedFiles = [first, second]
        state.outputFormat = "mp3"
        let completed = BatchStatusSnapshot(
            fileName: "voice-note.wav",
            state: .succeeded(outputURL: URL(fileURLWithPath: "/tmp/voice-note.mp3"))
        )

        state.startConversion()
        session.emitCompletion([completed])

        state.removeSelectedFile(SelectedAudioFile(url: first))

        XCTAssertEqual(state.selectedFiles, [second])
        XCTAssertTrue(state.batchSnapshots.isEmpty)
        XCTAssertTrue(state.canStartConversion)
        XCTAssertTrue(state.canRemoveSelectedFiles)
    }

    func testRemoveSelectedFileCanClearFinalStagedFile() {
        let state = makeReadyAppState()
        let onlyFile = URL(fileURLWithPath: "/tmp/voice-note.wav")
        state.selectedFiles = [onlyFile]
        state.outputFormat = "mp3"

        state.removeSelectedFile(SelectedAudioFile(url: onlyFile))

        XCTAssertTrue(state.selectedFiles.isEmpty)
        XCTAssertFalse(state.canStartConversion)
        XCTAssertFalse(state.canRemoveSelectedFiles)
    }

    func testClearAllFilesRemovesSelectionAndMergeDestination() {
        let state = makeReadyAppState(
            selectMergeDestinationURL: { _, _ in
                URL(fileURLWithPath: "/tmp/merged-output.mp3")
            }
        )
        state.operationMode = .mergeIntoOne
        state.selectedFiles = [
            URL(fileURLWithPath: "/tmp/voice-note.wav"),
            URL(fileURLWithPath: "/tmp/session.aiff")
        ]
        state.outputFormat = "mp3"
        state.selectMergeDestination()

        state.clearAllFiles()

        XCTAssertTrue(state.selectedFiles.isEmpty)
        XCTAssertNil(state.mergeDestinationURL)
        XCTAssertFalse(state.canStartMerge)
    }

    func testPreferredFormatAndModeRestoreFromPreferencesStore() {
        let preferencesStore = makePreferencesStore()
        preferencesStore.set("flac", forKey: "AudioConverter.preferredFormat")
        preferencesStore.set(AppState.OperationMode.mergeIntoOne.rawValue, forKey: "AudioConverter.preferredOperationMode")

        let state = AppState(preferencesStore: preferencesStore)

        XCTAssertEqual(state.outputFormat, "flac")
        XCTAssertEqual(state.operationMode, .mergeIntoOne)
    }

    func testChangingFormatAndModePersistsToPreferencesStore() {
        let preferencesStore = makePreferencesStore()
        let state = AppState(preferencesStore: preferencesStore)

        state.outputFormat = "wav"
        state.operationMode = .mergeIntoOne

        XCTAssertEqual(preferencesStore.string(forKey: "AudioConverter.preferredFormat"), "wav")
        XCTAssertEqual(
            preferencesStore.string(forKey: "AudioConverter.preferredOperationMode"),
            AppState.OperationMode.mergeIntoOne.rawValue
        )
    }

    func testQueueStateRestoresPausedStagedFilesAndSchedulerSettings() {
        let preferencesStore = makePreferencesStore()
        let firstFile = URL(fileURLWithPath: "/tmp/intro.wav")
        let secondFile = URL(fileURLWithPath: "/tmp/outro.aiff")
        let destinationURL = URL(fileURLWithPath: "/tmp/merged-output.mp3")
        let state = makeReadyAppState(
            selectMergeDestinationURL: { _, _ in destinationURL },
            preferencesStore: preferencesStore
        )
        state.operationMode = .mergeIntoOne
        state.selectedFiles = [firstFile, secondFile]
        state.outputFormat = "mp3"
        state.selectMergeDestination()
        state.operationMode = .batchConvert
        state.setAutomaticSchedulingEnabled(false)
        state.updateManualConcurrentJobLimit(4)

        let restoredState = AppState(preferencesStore: preferencesStore)

        XCTAssertEqual(restoredState.selectedFiles, [firstFile, secondFile])
        XCTAssertEqual(restoredState.mergeDestinationURL, destinationURL)
        XCTAssertEqual(restoredState.operationMode, .batchConvert)
        XCTAssertFalse(restoredState.schedulerSettings.usesAutomaticConcurrency)
        XCTAssertEqual(restoredState.manualConcurrentJobLimit, 4)
        XCTAssertFalse(restoredState.isConverting)
        XCTAssertTrue(restoredState.batchSnapshots.isEmpty)
    }

    func testQueueSchedulerSettingsClampManualConcurrencyAndDefaultToAutomaticLimit() {
        XCTAssertEqual(QueueSchedulerSettings.automaticLimit(processorCount: 1), 1)
        XCTAssertEqual(QueueSchedulerSettings.automaticLimit(processorCount: 4), 3)
        XCTAssertEqual(QueueSchedulerSettings.automaticLimit(processorCount: 12), 6)

        var settings = QueueSchedulerSettings(usesAutomaticConcurrency: false, manualConcurrentJobLimit: 99)
        XCTAssertEqual(settings.effectiveConcurrentJobLimit, QueueSchedulerSettings.maximumConcurrentJobLimit)

        settings.updateManualConcurrentJobLimit(0)
        XCTAssertEqual(settings.effectiveConcurrentJobLimit, QueueSchedulerSettings.minimumConcurrentJobLimit)
    }

    func testStartConversionPassesEffectiveSchedulerLimitIntoSessionFactory() {
        let session = ControlledConversionSession()
        var capturedMaximumConcurrentJobs: Int?
        let state = makeReadyAppState(
            session: session,
            makeConversionSession: { _, _, _, maximumConcurrentJobs, onUpdate, onCompletion in
                capturedMaximumConcurrentJobs = maximumConcurrentJobs
                session.onUpdate = onUpdate
                session.onCompletion = onCompletion
                return session
            }
        )

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "mp3"
        state.setAutomaticSchedulingEnabled(false)
        state.updateManualConcurrentJobLimit(3)

        state.startConversion()

        XCTAssertEqual(capturedMaximumConcurrentJobs, 3)
        XCTAssertEqual(session.startCallCount, 1)
    }

    func testMergeModeRequiresDestinationAndAtLeastTwoFiles() {
        let state = makeReadyAppState(
            selectMergeDestinationURL: { _, _ in
                URL(fileURLWithPath: "/tmp/merged-output.mp3")
            }
        )
        state.operationMode = .mergeIntoOne
        state.outputFormat = "mp3"

        XCTAssertFalse(state.canStartMerge)

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/intro.wav")]
        XCTAssertFalse(state.canStartMerge)

        state.selectedFiles = [
            URL(fileURLWithPath: "/tmp/intro.wav"),
            URL(fileURLWithPath: "/tmp/verse.wav")
        ]

        XCTAssertTrue(state.canChooseMergeDestination)
        XCTAssertFalse(state.canStartMerge)

        state.selectMergeDestination()

        XCTAssertEqual(state.mergeDestinationURL, URL(fileURLWithPath: "/tmp/merged-output.mp3"))
        XCTAssertTrue(state.canStartMerge)
    }

    func testMoveSelectedFileUpReordersFilesOnlyInMergeMode() {
        let state = makeReadyAppState()
        let first = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav"))
        let second = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/verse.wav"))
        let third = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/outro.wav"))
        state.selectedFiles = [first.url, second.url, third.url]

        state.moveSelectedFileUp(second)
        XCTAssertEqual(state.selectedFiles, [first.url, second.url, third.url])

        state.operationMode = .mergeIntoOne
        state.moveSelectedFileUp(second)
        XCTAssertEqual(state.selectedFiles, [second.url, first.url, third.url])

        state.moveSelectedFileDown(second)
        XCTAssertEqual(state.selectedFiles, [first.url, second.url, third.url])
    }

    func testStartMergeDispatchesOrderedFilesAndDestinationIntoMergeSession() {
        let session = ControlledMergeSession()
        let destinationURL = URL(fileURLWithPath: "/tmp/final-mix.mp3")
        let state = makeReadyAppState(
            session: ControlledConversionSession(),
            mergeSession: session,
            selectMergeDestinationURL: { _, _ in destinationURL }
        )
        let first = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/intro.wav"))
        let second = SelectedAudioFile(url: URL(fileURLWithPath: "/tmp/verse.wav"))

        state.operationMode = .mergeIntoOne
        state.selectedFiles = [first.url, second.url]
        state.outputFormat = "mp3"
        state.moveSelectedFileUp(second)
        state.selectMergeDestination()
        state.startPrimaryAction()

        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertEqual(session.capturedFiles.map(\.url), [second.url, first.url])
        XCTAssertEqual(session.capturedDestinationURL, destinationURL)
        XCTAssertTrue(state.isConverting)
    }

    func testStartConversionConsumesLiveSessionUpdatesBeforeCompletion() {
        let session = ControlledConversionSession()
        let state = makeReadyAppState(session: session)
        let snapshotID = UUID()
        let queued = BatchStatusSnapshot(id: snapshotID, fileName: "example.wav", state: .queued)
        let running = queued
            .updating(state: .running)
            .updatingProgress(
                fractionCompleted: 0.5,
                isIndeterminate: false,
                progressDetail: "50% complete"
            )
        let completed = queued.updating(state: .succeeded(outputURL: URL(fileURLWithPath: "/tmp/example.mp3")))

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "mp3"
        session.onStart = {
            session.emitUpdate([queued])
            session.emitUpdate([running])
        }

        state.startConversion()

        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertTrue(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertTrue(state.canCancelConversion)
        XCTAssertEqual(state.batchSnapshots, [running])
        XCTAssertEqual(state.batchSnapshots.first?.progressPercentText, "50%")
        XCTAssertEqual(state.batchSnapshots.first?.displayedDetail, "50% complete")

        session.emitCompletion([completed])

        XCTAssertFalse(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertFalse(state.canCancelConversion)
        XCTAssertEqual(state.batchSnapshots, [completed])
        XCTAssertEqual(state.statusMessage, "Finished conversion to MP3: 1 converted.")
    }

    func testCancelConversionRequestsSessionCancellationAndTracksCancelledCompletion() {
        let session = ControlledConversionSession()
        let state = makeReadyAppState(session: session)
        let snapshotID = UUID()
        let queued = BatchStatusSnapshot(id: snapshotID, fileName: "example.wav", state: .queued)
        let cancelled = queued.updating(state: .cancelled)

        state.selectedFiles = [URL(fileURLWithPath: "/tmp/example.wav")]
        state.outputFormat = "mp3"
        session.onStart = {
            session.emitUpdate([queued])
        }

        state.startConversion()
        state.cancelConversion()

        XCTAssertEqual(session.cancelCallCount, 1)
        XCTAssertTrue(state.isConverting)
        XCTAssertTrue(state.isCancelling)
        XCTAssertFalse(state.canCancelConversion)
        XCTAssertEqual(state.statusMessage, "Cancelling current batch…")

        session.emitUpdate([cancelled])
        session.emitCompletion([cancelled])

        XCTAssertFalse(state.isConverting)
        XCTAssertFalse(state.isCancelling)
        XCTAssertEqual(state.batchSnapshots, [cancelled])
        XCTAssertEqual(state.statusMessage, "Finished conversion to MP3: 1 cancelled.")
    }

    private func makeReadyAppState(
        session: ControlledConversionSession? = nil,
        mergeSession: ControlledMergeSession? = nil,
        selectAudioFiles: @escaping AppState.FileSelector = { [] },
        selectMergeDestinationURL: @escaping AppState.MergeDestinationSelector = { _, _ in nil },
        preferencesStore: UserDefaults? = nil,
        makeConversionSession: AppState.ConversionSessionFactory? = nil
    ) -> AppState {
        let controlledSession = session ?? ControlledConversionSession()
        let controlledMergeSession = mergeSession ?? ControlledMergeSession()
        let state = AppState(
            resolveFFmpegURL: { .ready(URL(fileURLWithPath: "/bin/sh")) },
            validateStartupCapabilities: { _ in .ready },
            selectAudioFiles: selectAudioFiles,
            selectMergeDestinationURL: selectMergeDestinationURL,
            preferencesStore: preferencesStore ?? makePreferencesStore(),
            makeConversionSession: makeConversionSession ?? { _, _, _, _, onUpdate, onCompletion in
                controlledSession.onUpdate = onUpdate
                controlledSession.onCompletion = onCompletion
                return controlledSession
            },
            makeMergeSession: { files, format, destinationURL, ffmpegURL, onUpdate, onCompletion in
                controlledMergeSession.capturedFiles = files
                controlledMergeSession.capturedFormat = format
                controlledMergeSession.capturedDestinationURL = destinationURL
                controlledMergeSession.capturedFFmpegURL = ffmpegURL
                controlledMergeSession.onUpdate = onUpdate
                controlledMergeSession.onCompletion = onCompletion
                return controlledMergeSession
            }
        )
        state.performStartupChecks()
        waitForStartupState(of: state) { $0 == .ready }
        return state
    }

    private func waitForStartupState(
        of state: AppState,
        timeout: TimeInterval = 1,
        matches predicate: (StartupState) -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)

        while !predicate(state.startupState) && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        XCTAssertTrue(predicate(state.startupState), "Timed out waiting for startup state, got \(state.startupState)")
    }

    private func makePreferencesStore() -> UserDefaults {
        let suiteName = "AudioConverterTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        store.removePersistentDomain(forName: suiteName)
        return store
    }

    @MainActor
    private func assertDefaultCanvasRender(
        state: AppState,
        artifactPath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let view = ZStack {
            Color(nsColor: .windowBackgroundColor)
            MainView()
                .environmentObject(state)
        }
        .environment(\.colorScheme, .dark)
        .frame(width: 980, height: 760)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        guard let image = renderer.nsImage else {
            XCTFail("MainView should render into an NSImage at the default window size.", file: file, line: line)
            return
        }

        XCTAssertEqual(image.size.width, 980, file: file, line: line)
        XCTAssertEqual(image.size.height, 760, file: file, line: line)

        let pngData = try XCTUnwrap(pngData(from: image), file: file, line: line)
        XCTAssertGreaterThan(pngData.count, 16_000, file: file, line: line)

        try pngData.write(to: URL(fileURLWithPath: artifactPath))
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

private final class ControlledConversionSession: BatchConversionSessioning {
    var onStart: (() -> Void)?
    var onUpdate: (([BatchStatusSnapshot]) -> Void)?
    var onCompletion: (([BatchStatusSnapshot]) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    func start() {
        startCallCount += 1
        onStart?()
    }

    func cancelAll() {
        cancelCallCount += 1
    }

    func emitUpdate(_ snapshots: [BatchStatusSnapshot]) {
        onUpdate?(snapshots)
    }

    func emitCompletion(_ snapshots: [BatchStatusSnapshot]) {
        onCompletion?(snapshots)
    }
}

private final class ControlledMergeSession: BatchConversionSessioning {
    var onUpdate: (([BatchStatusSnapshot]) -> Void)?
    var onCompletion: (([BatchStatusSnapshot]) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0
    var capturedFiles: [SelectedAudioFile] = []
    var capturedFormat: SupportedFormat?
    var capturedDestinationURL: URL?
    var capturedFFmpegURL: URL?

    func start() {
        startCallCount += 1
    }

    func cancelAll() {
        cancelCallCount += 1
    }
}
