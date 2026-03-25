import Foundation

final class MergeExportSession: BatchConversionSessioning {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private let files: [SelectedAudioFile]
    private let format: SupportedFormat
    private let ffmpegURL: URL
    private let destinationURL: URL
    private let engine: MergeExportEngine
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let processingQueue = DispatchQueue(label: "AudioConverter.MergeExportSession")
    private let lock = NSLock()
    private let snapshotID = UUID()

    private var state: ConversionItemState = .queued
    private var fractionCompleted: Double?
    private var isIndeterminate = false
    private var progressDetail: String?
    private var hasStarted = false
    private var hasCompleted = false
    private var cancellationRequested = false
    private var runningHandle: ConversionExecutionHandle?

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        destinationURL: URL,
        ffmpegURL: URL,
        engine: MergeExportEngine = MergeExportEngine(),
        onUpdate: @escaping SnapshotHandler = { _ in },
        onCompletion: @escaping SnapshotHandler = { _ in }
    ) {
        self.files = files
        self.format = format
        self.destinationURL = destinationURL
        self.ffmpegURL = ffmpegURL
        self.engine = engine
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
    }

    func start() {
        let initialSnapshots: [BatchStatusSnapshot]

        lock.lock()
        guard !hasStarted else {
            lock.unlock()
            return
        }
        hasStarted = true
        initialSnapshots = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(initialSnapshots)

        processingQueue.async { [weak self] in
            self?.runMerge()
        }
    }

    func cancelAll() {
        let snapshotsToPublish: [BatchStatusSnapshot]
        let currentHandle: ConversionExecutionHandle?
        let shouldFinishImmediately: Bool

        lock.lock()
        guard hasStarted, !hasCompleted, !cancellationRequested else {
            lock.unlock()
            return
        }

        cancellationRequested = true
        currentHandle = runningHandle
        if case .queued = state {
            state = .cancelled
        }
        if case .running = state {
            state = .cancelled
            fractionCompleted = nil
            isIndeterminate = false
            progressDetail = nil
        }
        snapshotsToPublish = [makeSnapshotLocked()]
        shouldFinishImmediately = currentHandle == nil
        lock.unlock()

        onUpdate(snapshotsToPublish)
        currentHandle?.cancel()

        if shouldFinishImmediately {
            finishIfNeeded()
        }
    }

    private func runMerge() {
        if isCancellationRequested {
            finishIfNeeded()
            return
        }

        switch engine.makeJob(for: files, format: format, destinationURL: destinationURL) {
        case let .failure(failureState):
            publishState(isCancellationRequested ? .cancelled : failureState)
            finishIfNeeded()

        case let .success(job):
            switch engine.start(
                job: job,
                ffmpegURL: ffmpegURL,
                onProgress: { [weak self] progress in
                    self?.publishProgress(progress)
                }
            ) {
            case let .failure(failureState):
                publishState(isCancellationRequested ? .cancelled : failureState)
                finishIfNeeded()

            case let .success(handle):
                setRunningHandle(handle)
                if isCancellationRequested {
                    handle.cancel()
                } else {
                    publishState(.running)
                }

                let terminalState = handle.waitForCompletion()
                clearRunningHandle(handle)
                publishState(isCancellationRequested ? .cancelled : terminalState)
                finishIfNeeded()
            }
        }
    }

    private var isCancellationRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private func setRunningHandle(_ handle: ConversionExecutionHandle) {
        lock.lock()
        runningHandle = handle
        lock.unlock()
    }

    private func clearRunningHandle(_ handle: ConversionExecutionHandle) {
        lock.lock()
        if runningHandle === handle {
            runningHandle = nil
        }
        lock.unlock()
    }

    private func publishState(_ nextState: ConversionItemState) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted else {
            lock.unlock()
            return
        }

        state = nextState
        switch nextState {
        case .running:
            fractionCompleted = nil
            isIndeterminate = true
            progressDetail = nil
        case .queued:
            fractionCompleted = nil
            isIndeterminate = false
            progressDetail = nil
        case .succeeded, .failed, .skipped, .cancelled:
            fractionCompleted = nil
            isIndeterminate = false
            progressDetail = nil
        }
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func publishProgress(_ progress: ConversionProgress) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted, !cancellationRequested, !state.isTerminal else {
            lock.unlock()
            return
        }

        let nextFractionCompleted: Double?
        if let existingFractionCompleted = fractionCompleted,
           let incomingFractionCompleted = progress.fractionCompleted {
            nextFractionCompleted = max(existingFractionCompleted, incomingFractionCompleted)
        } else {
            nextFractionCompleted = progress.fractionCompleted
        }

        state = .running
        fractionCompleted = nextFractionCompleted
        isIndeterminate = progress.isIndeterminate
        progressDetail = progress.progressDetail
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func finishIfNeeded() {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard !hasCompleted else {
            lock.unlock()
            return
        }
        hasCompleted = true
        snapshotsToPublish = [makeSnapshotLocked()]
        lock.unlock()

        onCompletion(snapshotsToPublish)
    }

    private func makeSnapshotLocked() -> BatchStatusSnapshot {
        BatchStatusSnapshot(
            id: snapshotID,
            fileName: destinationURL.lastPathComponent,
            state: state,
            fractionCompleted: state == .running ? fractionCompleted : nil,
            isIndeterminate: state == .running ? isIndeterminate : false,
            progressDetail: state == .running ? progressDetail : nil
        )
    }
}

struct MergeExportCoordinator {
    private let engine: MergeExportEngine

    init(engine: MergeExportEngine = MergeExportEngine()) {
        self.engine = engine
    }

    func makeSession(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        destinationURL: URL,
        ffmpegURL: URL,
        onUpdate: @escaping MergeExportSession.SnapshotHandler = { _ in },
        onCompletion: @escaping MergeExportSession.SnapshotHandler = { _ in }
    ) -> MergeExportSession {
        MergeExportSession(
            files: files,
            format: format,
            destinationURL: destinationURL,
            ffmpegURL: ffmpegURL,
            engine: engine,
            onUpdate: onUpdate,
            onCompletion: onCompletion
        )
    }
}
