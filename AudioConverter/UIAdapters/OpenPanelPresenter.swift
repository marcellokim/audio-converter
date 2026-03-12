import Foundation

struct OpenPanelPresenter {
    private let adapter: OpenPanelAdapting

    init(adapter: OpenPanelAdapting = OpenPanelAdapter()) {
        self.adapter = adapter
    }

    func selectFiles() -> [SelectedAudioFile] {
        adapter.chooseAudioFiles().map(SelectedAudioFile.init)
    }
}
