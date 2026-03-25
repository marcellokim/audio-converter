import Foundation

struct SavePanelPresenter {
    private let adapter: SavePanelAdapting

    init(adapter: SavePanelAdapting = SavePanelAdapter()) {
        self.adapter = adapter
    }

    func chooseDestination(for format: SupportedFormat, suggestedBaseName: String = "merged-audio") -> URL? {
        let suggestedFileName: String
        let existingExtension = (suggestedBaseName as NSString).pathExtension.lowercased()
        if existingExtension == format.outputExtension.lowercased() {
            suggestedFileName = suggestedBaseName
        } else {
            suggestedFileName = suggestedBaseName + "." + format.outputExtension
        }

        return adapter.chooseDestination(
            suggestedFileName: suggestedFileName,
            fileExtension: format.outputExtension
        )
    }
}
