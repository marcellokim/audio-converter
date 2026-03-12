import Foundation

enum ConversionItemState: Error, Equatable {
    case queued
    case running
    case succeeded(outputURL: URL)
    case failed(reason: FailureReason)
    case skipped(reason: SkipReason)

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
        }
    }
}
