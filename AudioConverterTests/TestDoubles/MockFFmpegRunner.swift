import Foundation
@testable import AudioConverter

final class MockFFmpegRunner: FFmpegRunning {
    enum RunnerError: Error {
        case launchFailed
    }

    final class Task: FFmpegTaskRunning {
        private let lock = NSLock()
        private let completionSemaphore = DispatchSemaphore(value: 0)

        private var completion: Result<FFmpegRunResult, Error>?
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?

        init(result: Result<FFmpegRunResult, Error>? = nil) {
            completion = result
        }

        func wait() throws -> FFmpegRunResult {
            while true {
                lock.lock()
                if let completion {
                    lock.unlock()
                    return try completion.get()
                }
                lock.unlock()
                completionSemaphore.wait()
            }
        }

        func cancel() {
            let onCancel: (() -> Void)?

            lock.lock()
            cancelCount += 1
            onCancel = self.onCancel
            lock.unlock()

            onCancel?()
        }

        func complete(with result: Result<FFmpegRunResult, Error>) {
            let shouldSignal: Bool

            lock.lock()
            shouldSignal = completion == nil
            completion = result
            lock.unlock()

            if shouldSignal {
                completionSemaphore.signal()
            }
        }
    }

    var results: [Result<FFmpegRunResult, Error>] = []
    var startResults: [Result<Task, Error>] = []
    private(set) var invocations: [(ffmpegURL: URL, arguments: [String])] = []
    private(set) var startedTasks: [Task] = []

    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        invocations.append((ffmpegURL, arguments))

        if !startResults.isEmpty {
            let next = startResults.removeFirst()
            switch next {
            case let .success(task):
                startedTasks.append(task)
                return task
            case let .failure(error):
                throw error
            }
        }

        let task: Task
        if !results.isEmpty {
            task = Task(result: results.removeFirst())
        } else {
            task = Task(result: .success(FFmpegRunResult(terminationStatus: 0, standardOutput: "", standardError: "")))
        }

        startedTasks.append(task)
        return task
    }
}

private final class ImmediateFFmpegTask: FFmpegTaskRunning {
    private let result: Result<FFmpegRunResult, Error>

    init(result: Result<FFmpegRunResult, Error>) {
        self.result = result
    }

    func wait() throws -> FFmpegRunResult {
        try result.get()
    }

    func cancel() {}
}

extension FFmpegRunner {
    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult {
        try start(ffmpegURL: ffmpegURL, arguments: arguments).wait()
    }
}

extension SpyFFmpegRunner {
    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        capturedURL = ffmpegURL
        capturedArguments = arguments

        if let error {
            throw error
        }

        return ImmediateFFmpegTask(result: .success(result))
    }
}
