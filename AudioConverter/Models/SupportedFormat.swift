import Foundation

struct SupportedFormat: Identifiable, Equatable {
    let id: String
    let displayName: String
    let outputExtension: String
    let requiredEncoderKey: String
    let requiredMuxerKey: String
    let ffmpegArgs: [String]

    init(
        id: String,
        displayName: String,
        outputExtension: String,
        requiredEncoderKey: String,
        requiredMuxerKey: String,
        ffmpegArgs: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.outputExtension = outputExtension
        self.requiredEncoderKey = requiredEncoderKey
        self.requiredMuxerKey = requiredMuxerKey
        self.ffmpegArgs = ffmpegArgs
    }
}
