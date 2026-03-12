import Foundation

protocol BatchStatusPresenting {
    func makeSnapshot(fileName: String, state: ConversionItemState) -> BatchStatusSnapshot
}

struct BatchStatusPresenter: BatchStatusPresenting {
    func makeSnapshot(fileName: String, state: ConversionItemState) -> BatchStatusSnapshot {
        BatchStatusSnapshot(
            fileName: fileName,
            state: state,
            detail: detail(for: state)
        )
    }

    private func detail(for state: ConversionItemState) -> String {
        switch state {
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
        }
    }
}
