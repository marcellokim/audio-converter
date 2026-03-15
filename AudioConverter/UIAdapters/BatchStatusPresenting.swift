import Foundation

protocol BatchStatusPresenting {
    func makeSnapshot(fileName: String, state: ConversionItemState) -> BatchStatusSnapshot
}

struct BatchStatusPresenter: BatchStatusPresenting {
    func makeSnapshot(fileName: String, state: ConversionItemState) -> BatchStatusSnapshot {
        BatchStatusSnapshot(fileName: fileName, state: state)
    }
}
