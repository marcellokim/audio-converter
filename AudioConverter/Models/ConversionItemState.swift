import Foundation

enum ConversionItemState: Error, Equatable {
    case queued
    case running
    case succeeded(outputURL: URL)
    case failed(reason: FailureReason)
    case skipped(reason: SkipReason)
    case cancelled

    var label: String {
        switch self {
        case .queued:
            return "Queued"
        case .running:
            return "Running"
        case .succeeded:
            return "Complete"
        case .failed:
            return "Failed"
        case .skipped:
            return "Skipped"
        case .cancelled:
            return "Cancelled"
        }
    }

    var detail: String {
        switch self {
        case .queued:
            return "Waiting in the studio queue."
        case .running:
            return "Rendering with ffmpeg."
        case let .succeeded(outputURL):
            return "Saved to \(outputURL.lastPathComponent)."
        case let .failed(reason):
            return reason.message
        case let .skipped(reason):
            return reason.message
        case .cancelled:
            return "Cancelled before completion."
        }
    }

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .skipped, .cancelled:
            return true
        case .queued, .running:
            return false
        }
    }

    var isQueued: Bool {
        if case .queued = self {
            return true
        }

        return false
    }
}
