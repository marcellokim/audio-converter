import Foundation

final class BatchConversionSession {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private struct SessionItem {
        let id: UUID
        let file: SelectedAudioFile
        var state: ConversionItemState
    }

    private let engine: ConversionEngine
    private let format: SupportedFormat
    private let ffmpegURL: URL
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let processingQueue = DispatchQueue(label: "AudioConverter.BatchConversionSession")
    private let lock = NSLock()

    private var items: [SessionItem]
    private var hasStarted = false
    private var hasCompleted = false
    private var cancellationRequested = false
    private var activeIndex: Int?
    private var runningHandle: ConversionExecutionHandle?

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL,
        engine: ConversionEngine,
        onUpdate: @escaping SnapshotHandler = { _ in },
        onCompletion: @escaping SnapshotHandler = { _ in }
    ) {
        self.engine = engine
        self.format = format
        self.ffmpegURL = ffmpegURL
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion
        items = files.map {
            SessionItem(id: UUID(), file: $0, state: .queued)
        }
    }

    var snapshots: [BatchStatusSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return items.map(makeSnapshot(for:))
    }

    func start() {
        let initialSnapshots: [BatchStatusSnapshot]

        lock.lock()
        guard !hasStarted else {
            lock.unlock()
            return
        }
        hasStarted = true
        initialSnapshots = items.map(makeSnapshot(for:))
        lock.unlock()

        onUpdate(initialSnapshots)

        processingQueue.async { [weak self] in
            self?.runSerialLoop()
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
        for index in items.indices where items[index].state.isQueued {
            items[index].state = .cancelled
        }
        snapshotsToPublish = items.map(makeSnapshot(for:))
        currentHandle = runningHandle
        shouldFinishImmediately = currentHandle == nil && activeIndex == nil
        lock.unlock()

        onUpdate(snapshotsToPublish)
        currentHandle?.cancel()

        if shouldFinishImmediately {
            finishIfNeeded()
        }
    }

    private func runSerialLoop() {
        while let nextIndex = nextQueuedIndex() {
            if isCancellationRequested {
                break
            }

            setActiveIndex(nextIndex)
            let file = item(at: nextIndex).file
            let jobResult = engine.makeJob(for: file, format: format)

            if isCancellationRequested {
                clearActiveIndex(nextIndex)
                break
            }

            switch jobResult {
            case let .failure(state):
                publishState(state, for: nextIndex)
                clearActiveIndex(nextIndex)

            case let .success(job):
                switch engine.start(job: job, ffmpegURL: ffmpegURL) {
                case let .failure(state):
                    if isCancellationRequested {
                        publishState(.cancelled, for: nextIndex)
                    } else {
                        publishState(state, for: nextIndex)
                    }
                    clearActiveIndex(nextIndex)

                case let .success(handle):
                    setRunningHandle(handle)
                    if isCancellationRequested {
                        handle.cancel()
                    } else {
                        publishState(.running, for: nextIndex)
                    }
                    let terminalState = handle.waitForCompletion()
                    clearRunningHandle(handle)
                    clearActiveIndex(nextIndex)
                    publishState(terminalState, for: nextIndex)

                    if isCancellationRequested {
                        break
                    }
                }
            }
        }

        finishIfNeeded()
    }

    private var isCancellationRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private func nextQueuedIndex() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return items.firstIndex { $0.state.isQueued }
    }

    private func item(at index: Int) -> SessionItem {
        lock.lock()
        defer { lock.unlock() }
        return items[index]
    }

    private func setActiveIndex(_ index: Int) {
        lock.lock()
        activeIndex = index
        lock.unlock()
    }

    private func clearActiveIndex(_ index: Int) {
        lock.lock()
        if activeIndex == index {
            activeIndex = nil
        }
        lock.unlock()
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

    private func publishState(_ state: ConversionItemState, for index: Int) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard items.indices.contains(index), !hasCompleted else {
            lock.unlock()
            return
        }
        items[index].state = state
        snapshotsToPublish = items.map(makeSnapshot(for:))
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
        snapshotsToPublish = items.map(makeSnapshot(for:))
        lock.unlock()

        onCompletion(snapshotsToPublish)
    }

    private func makeSnapshot(for item: SessionItem) -> BatchStatusSnapshot {
        BatchStatusSnapshot(id: item.id, fileName: item.file.displayName, state: item.state)
    }
}

struct ConversionCoordinator {
    private let engine: ConversionEngine
    private let presenter: BatchStatusPresenting
    let maximumConcurrentJobs: Int

    init(
        engine: ConversionEngine = ConversionEngine(),
        presenter: BatchStatusPresenting = BatchStatusPresenter(),
        maximumConcurrentJobs: Int = 2
    ) {
        self.engine = engine
        self.presenter = presenter
        self.maximumConcurrentJobs = max(1, min(maximumConcurrentJobs, 2))
    }

    func makeSession(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL,
        onUpdate: @escaping BatchConversionSession.SnapshotHandler = { _ in },
        onCompletion: @escaping BatchConversionSession.SnapshotHandler = { _ in }
    ) -> BatchConversionSession {
        _ = presenter
        _ = maximumConcurrentJobs

        return BatchConversionSession(
            files: files,
            format: format,
            ffmpegURL: ffmpegURL,
            engine: engine,
            onUpdate: onUpdate,
            onCompletion: onCompletion
        )
    }

    func process(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL
    ) -> [BatchStatusSnapshot] {
        let semaphore = DispatchSemaphore(value: 0)
        let stateLock = NSLock()
        var finalSnapshots: [BatchStatusSnapshot] = []

        let session = makeSession(
            files: files,
            format: format,
            ffmpegURL: ffmpegURL,
            onUpdate: { snapshots in
                stateLock.lock()
                finalSnapshots = snapshots
                stateLock.unlock()
            },
            onCompletion: { snapshots in
                stateLock.lock()
                finalSnapshots = snapshots
                stateLock.unlock()
                semaphore.signal()
            }
        )

        session.start()
        semaphore.wait()

        stateLock.lock()
        let snapshots = finalSnapshots
        stateLock.unlock()
        return snapshots
    }
}
