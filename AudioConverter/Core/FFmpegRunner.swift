import Foundation

struct FFmpegRunner: FFmpegRunning {
    func start(ffmpegURL: URL, arguments: [String]) throws -> FFmpegTaskRunning {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let task = ProcessBackedFFmpegTask(
            process: process,
            outputPipe: outputPipe,
            errorPipe: errorPipe
        )

        try process.run()
        return task
    }
}

private final class ProcessBackedFFmpegTask: FFmpegTaskRunning {
    private let process: Process
    private let outputPipe: Pipe
    private let errorPipe: Pipe
    private let lock = NSLock()

    private var cancellationRequested = false
    private var progressHandler: ((FFmpegProgressEvent) -> Void)?
    private var pendingProgressEvents: [FFmpegProgressEvent] = []
    private var outputBuffer = Data()
    private var outputLineBuffer = ""
    private var progressFrame: [String: String] = [:]

    init(process: Process, outputPipe: Pipe, errorPipe: Pipe) {
        self.process = process
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe
        configureOutputStreaming()
    }

    func wait() throws -> FFmpegRunResult {
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        consumeOutputData(outputPipe.fileHandleForReading.readDataToEndOfFile(), flushTrailingLine: true)

        lock.lock()
        let output = String(data: outputBuffer, encoding: .utf8) ?? ""
        let wasCancelled = cancellationRequested
        lock.unlock()

        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return FFmpegRunResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error,
            wasCancelled: wasCancelled
        )
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let shouldTerminate = process.isRunning
        lock.unlock()

        guard shouldTerminate else {
            return
        }

        process.terminate()
    }

    func setProgressHandler(_ handler: @escaping (FFmpegProgressEvent) -> Void) {
        let bufferedEvents: [FFmpegProgressEvent]

        lock.lock()
        progressHandler = handler
        bufferedEvents = pendingProgressEvents
        pendingProgressEvents.removeAll(keepingCapacity: true)
        lock.unlock()

        for event in bufferedEvents {
            handler(event)
        }
    }

    private func configureOutputStreaming() {
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }

            self?.consumeOutputData(data)
        }
    }

    private func consumeOutputData(_ data: Data, flushTrailingLine: Bool = false) {
        var emittedEvents: [FFmpegProgressEvent] = []
        let activeHandler: ((FFmpegProgressEvent) -> Void)?

        lock.lock()
        outputBuffer.append(data)
        if let chunk = String(data: data, encoding: .utf8) {
            outputLineBuffer += chunk

            while let newlineRange = outputLineBuffer.range(of: "\n") {
                let rawLine = String(outputLineBuffer[..<newlineRange.lowerBound])
                outputLineBuffer.removeSubrange(outputLineBuffer.startIndex..<newlineRange.upperBound)
                processProgressLine(rawLine, emittedEvents: &emittedEvents)
            }
        }

        if flushTrailingLine, !outputLineBuffer.isEmpty {
            let trailingLine = outputLineBuffer
            outputLineBuffer.removeAll(keepingCapacity: true)
            processProgressLine(trailingLine, emittedEvents: &emittedEvents)
        }

        activeHandler = progressHandler
        if activeHandler == nil {
            pendingProgressEvents.append(contentsOf: emittedEvents)
        }
        lock.unlock()

        if let activeHandler {
            for event in emittedEvents {
                activeHandler(event)
            }
        }
    }

    private func processProgressLine(_ rawLine: String, emittedEvents: inout [FFmpegProgressEvent]) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let separator = line.firstIndex(of: "=") else {
            return
        }

        let key = String(line[..<separator])
        let value = String(line[line.index(after: separator)...])
        progressFrame[key] = value

        if key == "progress" {
            emittedEvents.append(
                FFmpegProgressEvent(
                    outTimeSeconds: Self.parseOutTimeSeconds(from: progressFrame),
                    progressState: value
                )
            )
            progressFrame.removeAll(keepingCapacity: true)
        }
    }

    private static func parseOutTimeSeconds(from progressFrame: [String: String]) -> Double? {
        if let rawMicroseconds = progressFrame["out_time_us"],
           let microseconds = Double(rawMicroseconds) {
            return microseconds / 1_000_000
        }

        if let rawOutTime = progressFrame["out_time"] {
            return parseClockTime(rawOutTime)
        }

        if let rawMaybeMicroseconds = progressFrame["out_time_ms"],
           let maybeMicroseconds = Double(rawMaybeMicroseconds) {
            return maybeMicroseconds / 1_000_000
        }

        return nil
    }

    private static func parseClockTime(_ value: String) -> Double? {
        let components = value.split(separator: ":")
        guard components.count == 3,
              let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }

        return (hours * 3600) + (minutes * 60) + seconds
    }
}
