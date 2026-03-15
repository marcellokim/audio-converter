import Foundation
import XCTest
@testable import AudioConverter

final class OpenPanelPresenterTests: XCTestCase {
    func testSelectFilesMapsURLsToSelectedAudioFiles() {
        let urls = [
            URL(fileURLWithPath: "/tmp/first.wav"),
            URL(fileURLWithPath: "/tmp/second.aiff")
        ]
        let presenter = OpenPanelPresenter(adapter: StubOpenPanelAdapter(urls: urls))

        let files = presenter.selectFiles()

        XCTAssertEqual(files.map(\.url), urls)
        XCTAssertEqual(files.map(\.displayName), ["first.wav", "second.aiff"])
    }

    func testSelectFilesReturnsEmptyWhenUserCancelsPanel() {
        let presenter = OpenPanelPresenter(adapter: StubOpenPanelAdapter(urls: []))

        let files = presenter.selectFiles()

        XCTAssertTrue(files.isEmpty)
    }
}
