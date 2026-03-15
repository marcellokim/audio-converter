import Foundation

final class BatchConversionSession {
    typealias SnapshotHandler = ([BatchStatusSnapshot]) -> Void

    private let engine: ConversionEngine
    private let presenter: BatchStatusPresenting
    private let format: SupportedFormat
    private let ffmpegURL: URL
    private let onUpdate: SnapshotHandler
    private let onCompletion: SnapshotHandler
    private let workItems: [(file: SelectedAudioFile, id: UUID)]
    private let stateLock = NSLock()
    private let workQueue = DispatchQueue(label: "AudioConverter.BatchConversionSession", qos: .userInitiated)

    private var snapshots: [BatchStatusSnapshot]
    private var currentTask: FFmpegTaskRunning?
    private var isCancellationRequested = false
    private var isCompleted = false

    init(
        files: [SelectedAudioFile],
        format: SupportedFormat,
        ffmpegURL: URL,
        engine: ConversionEngine,
        presenter: BatchStatusPresenting,
        onUpdate: @escaping SnapshotHandler,
        onCompletion: @escaping SnapshotHandler
    ) {
        self.engine = engine
        self.presenter = presenter
        self.format = format
        self.ffmpegURL = ffmpegURL
        self.onUpdate = onUpdate
        self.onCompletion = onCompletion

        let items = files.map { (file: $0, id: UUID()) }
        workItems = items
        snapshots = items.map { item in
            Self.makeSnapshot(
                presenter: presenter,
                id: item.id,
                fileName: item.file.displayName,
                state: .queued
            )
        }

        let initialSnapshots = snapshots
        workQueue.async { [self] in
            onUpdate(initialSnapshots)
            runBatch()
        }
    }

    func cancelAll() {
        let currentTask: FFmpegTaskRunning?
        let updatedSnapshots: [BatchStatusSnapshot]

        stateLock.lock()

        guard !isCompleted, !isCancellationRequested else {
            stateLock.unlock()
            return
        }

        isCancellationRequested = true
        currentTask = self.currentTask
        snapshots = snapshots.map { snapshot in
            switch snapshot.state {
            case .queued:
                return Self.makeSnapshot(
                    presenter: presenter,
                    id: snapshot.id,
                    fileName: snapshot.fileName,
                    state: .cancelled
                )
            default:
                return snapshot
            }
        }
        updatedSnapshots = snapshots
        stateLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            currentTask?.cancel()
        }
        onUpdate(updatedSnapshots)
    }

    private func runBatch() {
        for item in workItems {
            if isCancellationRequestedState {
                continue
            }

            switch engine.makeJob(for: item.file, format: format) {
            case let .failure(state):
                if isCancellationRequestedState {
                    continue
                }
                updateSnapshot(id: item.id, fileName: item.file.displayName, state: state)

            case let .success(job):
                if isCancellationRequestedState {
                    continue
                }
                updateSnapshot(id: item.id, fileName: item.file.displayName, state: .running)

                let state = engine.run(
                    job: job,
                    ffmpegURL: ffmpegURL,
                    onTaskStarted: { [weak self] task in
                        self?.setCurrentTask(task)
                    },
                    isCancellationRequested: { [weak self] in
                        self?.isCancellationRequestedState ?? false
                    }
                )

                clearCurrentTask()
                updateSnapshot(id: item.id, fileName: item.file.displayName, state: state)
            }
        }

        complete()
    }

    private func updateSnapshot(id: UUID, fileName: String, state: ConversionItemState) {
        let nextSnapshots: [BatchStatusSnapshot]

        stateLock.lock()
        snapshots = snapshots.map { snapshot in
            guard snapshot.id == id else {
                return snapshot
            }

            return Self.makeSnapshot(
                presenter: presenter,
                id: snapshot.id,
                fileName: fileName,
                state: state
            )
        }
        nextSnapshots = snapshots
        stateLock.unlock()

        onUpdate(nextSnapshots)
    }

    private func complete() {
        let finalSnapshots: [BatchStatusSnapshot]

        stateLock.lock()
        isCompleted = true
        currentTask = nil
        finalSnapshots = snapshots
        stateLock.unlock()

        onCompletion(finalSnapshots)
    }

    private func setCurrentTask(_ task: FFmpegTaskRunning) {
        stateLock.lock()
        currentTask = task
        stateLock.unlock()
    }

    private func clearCurrentTask() {
        stateLock.lock()
        currentTask = nil
        stateLock.unlock()
    }

    private var isCancellationRequestedState: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isCancellationRequested
    }

    private static func makeSnapshot(
        presenter: BatchStatusPresenting,
        id: UUID,
        fileName: String,
        state: ConversionItemState
    ) -> BatchStatusSnapshot {
        let snapshot = presenter.makeSnapshot(fileName: fileName, state: state)
        return BatchStatusSnapshot(
            id: id,
            fileName: snapshot.fileName,
            state: snapshot.state,
            detail: snapshot.detail
        )
    }
}
