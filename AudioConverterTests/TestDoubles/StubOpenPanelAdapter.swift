import Foundation
@testable import AudioConverter

struct StubOpenPanelAdapter: OpenPanelAdapting {
    let urls: [URL]

    func chooseAudioFiles() -> [URL] {
        urls
    }
}
