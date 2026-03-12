import AppKit
import Foundation

protocol OpenPanelAdapting {
    func chooseAudioFiles() -> [URL]
}

struct OpenPanelAdapter: OpenPanelAdapting {
    func chooseAudioFiles() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Choose source audio"
        panel.message = "Select one or more audio files to batch convert."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true

        return panel.runModal() == .OK ? panel.urls : []
    }
}
