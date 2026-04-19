import Foundation
import XCTest
@testable import AudioConverter

final class FileManagingTests: XCTestCase {
    func testMakeTemporaryOutputURLUsesSameDirectoryAndPartialExtension() {
        let adapter = DefaultFileManagerAdapter()
        let destinationURL = URL(fileURLWithPath: "/tmp/render/final.aiff")

        let temporaryURL = adapter.makeTemporaryOutputURL(for: destinationURL)

        XCTAssertEqual(temporaryURL.deletingLastPathComponent(), destinationURL.deletingLastPathComponent())
        XCTAssertEqual(temporaryURL.pathExtension, "aiff")
        XCTAssertTrue(temporaryURL.lastPathComponent.hasPrefix(".final."))
        XCTAssertTrue(temporaryURL.lastPathComponent.contains(".partial."))
    }

    func testMoveItemAtomicallyThrowsWhenDestinationAlreadyExists() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let adapter = DefaultFileManagerAdapter()
        let sourceURL = tempDirectory.appendingPathComponent("source.tmp")
        let destinationURL = tempDirectory.appendingPathComponent("destination.tmp")
        try Data("source".utf8).write(to: sourceURL)
        try Data("destination".utf8).write(to: destinationURL)

        XCTAssertThrowsError(try adapter.moveItemAtomically(at: sourceURL, to: destinationURL)) { error in
            XCTAssertEqual((error as? CocoaError)?.code, .fileWriteFileExists)
        }
    }

    func testReplaceItemAtomicallyOverwritesExistingDestination() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let adapter = DefaultFileManagerAdapter()
        let sourceURL = tempDirectory.appendingPathComponent("source.tmp")
        let destinationURL = tempDirectory.appendingPathComponent("destination.tmp")
        try Data("replacement".utf8).write(to: sourceURL)
        try Data("existing".utf8).write(to: destinationURL)

        try adapter.replaceItemAtomically(at: sourceURL, to: destinationURL)

        XCTAssertEqual(try String(contentsOf: destinationURL), "replacement")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    func testRemoveItemIfPresentDeletesExistingFileAndIgnoresMissing() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let adapter = DefaultFileManagerAdapter()
        let targetURL = tempDirectory.appendingPathComponent("stale.partial.mp3")
        try Data().write(to: targetURL)

        adapter.removeItemIfPresent(at: targetURL)
        adapter.removeItemIfPresent(at: targetURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path))
    }
}
