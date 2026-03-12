import Foundation

struct FFmpegRunResult: Equatable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

protocol FFmpegRunning {
    func run(ffmpegURL: URL, arguments: [String]) throws -> FFmpegRunResult
}
