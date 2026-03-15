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

    func testSkippedConflictStateProducesReadableSnapshot() {
        let presenter = BatchStatusPresenter()

        let snapshot = presenter.makeSnapshot(
            fileName: "demo.wav",
            state: .skipped(reason: .conflictExistingOutput)
        )

        XCTAssertEqual(snapshot.fileName, "demo.wav")
        XCTAssertEqual(snapshot.state, .skipped(reason: .conflictExistingOutput))
        XCTAssertEqual(snapshot.detail, "A file already exists at the destination path, so overwrite was avoided.")
    }

    func testRunningStateProducesReadableSnapshot() {
        let presenter = BatchStatusPresenter()

        let snapshot = presenter.makeSnapshot(fileName: "demo.wav", state: .running)

        XCTAssertEqual(snapshot.fileName, "demo.wav")
        XCTAssertEqual(snapshot.state, .running)
        XCTAssertEqual(snapshot.detail, "Rendering with ffmpeg.")
    }
}
