import Foundation

struct BatchStatusSnapshot: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let state: ConversionItemState
    let detail: String
    let fractionCompleted: Double?
    let isIndeterminate: Bool
    let progressDetail: String?

    init(
        id: UUID = UUID(),
        fileName: String,
        state: ConversionItemState,
        detail: String? = nil,
        fractionCompleted: Double? = nil,
        isIndeterminate: Bool = false,
        progressDetail: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.state = state
        self.detail = detail ?? state.detail
        self.fractionCompleted = fractionCompleted
        self.isIndeterminate = isIndeterminate
        self.progressDetail = progressDetail
    }

    func updating(state: ConversionItemState) -> BatchStatusSnapshot {
        BatchStatusSnapshot(id: id, fileName: fileName, state: state)
    }

    func updatingProgress(
        fractionCompleted: Double?,
        isIndeterminate: Bool,
        progressDetail: String?
    ) -> BatchStatusSnapshot {
        BatchStatusSnapshot(
            id: id,
            fileName: fileName,
            state: state,
            detail: detail,
            fractionCompleted: fractionCompleted,
            isIndeterminate: isIndeterminate,
            progressDetail: progressDetail
        )
    }

    var displayedDetail: String {
        progressDetail ?? detail
    }

    var progressPercentText: String? {
        guard let fractionCompleted else {
            return nil
        }

        let percent = Int((min(max(fractionCompleted, 0), 1) * 100).rounded())
        return "\(percent)%"
    }
}
