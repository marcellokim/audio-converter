import Foundation

struct SelectedAudioFile: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL

    init(url: URL) {
        self.id = url
        self.url = url
    }

    var displayName: String {
        url.lastPathComponent
    }

    var directoryURL: URL {
        url.deletingLastPathComponent()
    }
}
