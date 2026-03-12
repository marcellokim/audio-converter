import Foundation
import XCTest
@testable import AudioConverter

final class BatchStatusPresenterTests: XCTestCase {
    func testSucceededStateProducesReadableSnapshot() {
        let presenter = BatchStatusPresenter()
        let outputURL = URL(fileURLWithPath: "/tmp/final.flac")

        let snapshot = presenter.makeSnapshot(fileName: "demo.wav", state: .succeeded(outputURL: outputURL))

        XCTAssertEqual(snapshot.fileName, "demo.wav")
        XCTAssertEqual(snapshot.state, .succeeded(outputURL: outputURL))
        XCTAssertEqual(snapshot.detail, "Saved to final.flac.")
    }
}
