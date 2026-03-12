import Foundation

struct FFmpegRunner: FFmpegRunning {
    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return FFmpegRunResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error
        )
    }
}
