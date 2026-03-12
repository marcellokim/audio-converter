import Foundation

enum FailureReason: Equatable {
    case ffmpegUnavailable
    case invalidInput
    case processLaunchFailed(String)
    case processFailed(String)
    case filesystem(String)

    var message: String {
        switch self {
        case .ffmpegUnavailable:
            return "The bundled ffmpeg binary is unavailable."
        case .invalidInput:
            return "The selected input could not be validated."
        case let .processLaunchFailed(details):
            return details
        case let .processFailed(details):
            return details
        case let .filesystem(details):
            return details
        }
    }
}
