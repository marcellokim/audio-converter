import Foundation

struct BatchStatusSnapshot: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let state: ConversionItemState
    let detail: String

    init(id: UUID = UUID(), fileName: String, state: ConversionItemState, detail: String) {
        self.id = id
        self.fileName = fileName
        self.state = state
        self.detail = detail
    }
}
