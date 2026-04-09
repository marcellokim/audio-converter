import Foundation

final class ConversionCoordinatorSession {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private struct SessionItem {
        let id: UUID
        let file: SelectedAudioFile
        var state: ConversionItemState
        var fractionCompleted: Double?
        var isIndeterminate: Bool
        var progressDetail: String?
    }

    private let engine: ConversionEngine
    private let format: SupportedFormat
    private let ffmpegURL: URL
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let processingQueue = DispatchQueue(label: "AudioConverter.ConversionCoordinatorSession")
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
            SessionItem(
                id: UUID(),
                file: $0,
                state: .queued,
                fractionCompleted: nil,
                isIndeterminate: false,
                progressDetail: nil
            )
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
                switch engine.start(
                    job: job,
                    ffmpegURL: ffmpegURL,
                    onProgress: { [weak self] progress in
                        self?.publishProgress(progress, for: nextIndex)
                    }
                ) {
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
        let previousState = items[index].state
        items[index].state = state
        switch state {
        case .running:
            if previousState != .running {
                items[index].fractionCompleted = nil
                items[index].isIndeterminate = true
                items[index].progressDetail = nil
            }
        case .queued:
            items[index].fractionCompleted = nil
            items[index].isIndeterminate = false
            items[index].progressDetail = nil
        case .succeeded, .failed, .skipped, .cancelled:
            items[index].fractionCompleted = nil
            items[index].isIndeterminate = false
            items[index].progressDetail = nil
        }
        snapshotsToPublish = items.map(makeSnapshot(for:))
        lock.unlock()

        onUpdate(snapshotsToPublish)
    }

    private func publishProgress(_ progress: ConversionProgress, for index: Int) {
        let snapshotsToPublish: [BatchStatusSnapshot]

        lock.lock()
        guard items.indices.contains(index), !hasCompleted, !cancellationRequested else {
            lock.unlock()
            return
        }

        guard !items[index].state.isTerminal else {
            lock.unlock()
            return
        }

        let nextFractionCompleted: Double?
        if let existingFraction = items[index].fractionCompleted,
           let incomingFraction = progress.fractionCompleted {
            nextFractionCompleted = max(existingFraction, incomingFraction)
        } else {
            nextFractionCompleted = progress.fractionCompleted
        }

        if items[index].state == .running,
           items[index].fractionCompleted == nextFractionCompleted,
           items[index].isIndeterminate == progress.isIndeterminate,
           items[index].progressDetail == progress.progressDetail {
            lock.unlock()
            return
        }

        items[index].state = .running
        items[index].fractionCompleted = nextFractionCompleted
        items[index].isIndeterminate = progress.isIndeterminate
        items[index].progressDetail = progress.progressDetail
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

struct ConversionCoordinator {
    private let engine: ConversionEngine

    init(engine: ConversionEngine = ConversionEngine()) {
        self.engine = engine
    }

    init(
        engine: ConversionEngine = ConversionEngine(),
        presenter _: BatchStatusPresenting = BatchStatusPresenter(),
        maximumConcurrentJobs _: Int = 2
    ) {
        self.init(engine: engine)
    }

    func makeSession(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL,
        onUpdate: @escaping ConversionCoordinatorSession.SnapshotHandler = { _ in },
        onCompletion: @escaping ConversionCoordinatorSession.SnapshotHandler = { _ in }
    ) -> ConversionCoordinatorSession {
        return ConversionCoordinatorSession(
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
