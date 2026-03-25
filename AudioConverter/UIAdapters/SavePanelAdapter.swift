import AppKit
import Foundation
import UniformTypeIdentifiers

protocol SavePanelAdapting {
    func chooseDestination(suggestedFileName: String, fileExtension: String) -> URL?
}

struct SavePanelAdapter: SavePanelAdapting {
    func chooseDestination(suggestedFileName: String, fileExtension: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Choose merged audio destination"
        panel.message = "Choose where the merged audio file should be saved."
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedFileName

        if let contentType = UTType(filenameExtension: fileExtension) {
            panel.allowedContentTypes = [contentType]
        }

        return panel.runModal() == .OK ? panel.url : nil
    }
}
