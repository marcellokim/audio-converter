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
    private let completionQueue = DispatchQueue(label: "AudioConverter.ConversionCoordinatorSession.completions", attributes: .concurrent)
    private let schedulerSemaphore = DispatchSemaphore(value: 0)
    private let maximumConcurrentJobs: Int
    private let lock = NSLock()

    private var items: [SessionItem]
    private var hasStarted = false
    private var hasCompleted = false
    private var cancellationRequested = false
    private var reservedOutputURLs: [Int: URL] = [:]
    private var runningHandles: [Int: ConversionExecutionHandle] = [:]

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL,
        engine: ConversionEngine,
        maximumConcurrentJobs: Int,
        onUpdate: @escaping SnapshotHandler = { _ in },
        onCompletion: @escaping SnapshotHandler = { _ in }
    ) {
        self.engine = engine
        self.format = format
        self.ffmpegURL = ffmpegURL
        self.maximumConcurrentJobs = max(maximumConcurrentJobs, 1)
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
            self?.runScheduledLoop()
        }
    }

    func cancelAll() {
        let snapshotsToPublish: [BatchStatusSnapshot]
        let currentHandles: [ConversionExecutionHandle]
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
        currentHandles = Array(runningHandles.values)
        shouldFinishImmediately = currentHandles.isEmpty && reservedOutputURLs.isEmpty
        lock.unlock()

        onUpdate(snapshotsToPublish)
        currentHandles.forEach { $0.cancel() }
        schedulerSemaphore.signal()

        if shouldFinishImmediately {
            finishIfNeeded()
        }
    }

    private func runScheduledLoop() {
        while true {
            if isCancellationRequested {
                guard activeJobCount > 0 else {
                    break
                }

                schedulerSemaphore.wait()
                continue
            }

            var didAdvance = false

            while activeJobCount < maximumConcurrentJobs {
                guard scheduleNextAvailableItem() else {
                    break
                }

                didAdvance = true

                if isCancellationRequested {
                    break
                }
            }

            if isCancellationRequested {
                continue
            }

            if activeJobCount == 0, queuedItemCount == 0 {
                break
            }

            if !didAdvance || activeJobCount >= maximumConcurrentJobs {
                schedulerSemaphore.wait()
            }
        }

        finishIfNeeded()
    }

    private func scheduleNextAvailableItem() -> Bool {
        for nextIndex in queuedIndices() {
            guard !isCancellationRequested else {
                return false
            }

            let file = item(at: nextIndex).file
            let jobResult = engine.makeJob(for: file, format: format)

            if isCancellationRequested {
                return false
            }

            switch jobResult {
            case let .failure(state):
                publishState(state, for: nextIndex)
                return true

            case let .success(job):
                guard reserveOutputURLIfAvailable(job.outputURL, for: nextIndex) else {
                    continue
                }

                guard !isCancellationRequested else {
                    releaseOutputURL(for: nextIndex)
                    publishState(.cancelled, for: nextIndex)
                    return true
                }

                switch engine.start(
                    job: job,
                    ffmpegURL: ffmpegURL,
                    onProgress: { [weak self] progress in
                        self?.publishProgress(progress, for: nextIndex)
                    }
                ) {
                case let .failure(state):
                    releaseOutputURL(for: nextIndex)
                    if isCancellationRequested {
                        publishState(.cancelled, for: nextIndex)
                    } else {
                        publishState(state, for: nextIndex)
                    }
                    schedulerSemaphore.signal()
                    return true

                case let .success(handle):
                    setRunningHandle(handle, for: nextIndex)
                    if isCancellationRequested {
                        handle.cancel()
                    } else {
                        publishState(.running, for: nextIndex)
                    }
                    completionQueue.async { [weak self] in
                        let terminalState = handle.waitForCompletion()
                        self?.completeRunningItem(handle, terminalState: terminalState, for: nextIndex)
                    }
                    return true
                }
            }
        }

        return false
    }

    private var isCancellationRequested: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellationRequested
    }

    private var activeJobCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return reservedOutputURLs.count
    }

    private var queuedItemCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return items.filter { $0.state.isQueued }.count
    }

    private func queuedIndices() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return items.indices.filter { items[$0].state.isQueued }
    }

    private func item(at index: Int) -> SessionItem {
        lock.lock()
        defer { lock.unlock() }
        return items[index]
    }

    private func reserveOutputURLIfAvailable(_ outputURL: URL, for index: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !reservedOutputURLs.values.contains(outputURL) else {
            return false
        }

        reservedOutputURLs[index] = outputURL
        return true
    }

    private func releaseOutputURL(for index: Int) {
        lock.lock()
        reservedOutputURLs[index] = nil
        lock.unlock()
    }

    private func setRunningHandle(_ handle: ConversionExecutionHandle, for index: Int) {
        lock.lock()
        runningHandles[index] = handle
        lock.unlock()
    }

    private func completeRunningItem(
        _ handle: ConversionExecutionHandle,
        terminalState: ConversionItemState,
        for index: Int
    ) {
        let shouldPublish: Bool

        lock.lock()
        shouldPublish = runningHandles[index] === handle
        if shouldPublish {
            runningHandles[index] = nil
            reservedOutputURLs[index] = nil
        }
        lock.unlock()

        guard shouldPublish else {
            schedulerSemaphore.signal()
            return
        }

        publishState(terminalState, for: index)
        schedulerSemaphore.signal()
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
    private static let maximumSupportedConcurrentJobs = 6

    private let engine: ConversionEngine
    private let maximumConcurrentJobs: Int

    init(engine: ConversionEngine = ConversionEngine(), maximumConcurrentJobs: Int = 2) {
        self.engine = engine
        self.maximumConcurrentJobs = Self.clampedConcurrentJobs(maximumConcurrentJobs)
    }

    init(
        engine: ConversionEngine = ConversionEngine(),
        presenter _: BatchStatusPresenting = BatchStatusPresenter(),
        maximumConcurrentJobs: Int = 2
    ) {
        self.init(engine: engine, maximumConcurrentJobs: maximumConcurrentJobs)
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
            maximumConcurrentJobs: maximumConcurrentJobs,
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

    private static func clampedConcurrentJobs(_ value: Int) -> Int {
        min(max(value, 1), maximumSupportedConcurrentJobs)
    }
}
