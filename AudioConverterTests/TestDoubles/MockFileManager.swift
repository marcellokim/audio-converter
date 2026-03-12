import Foundation
@testable import AudioConverter

final class MockFileManager: FileManaging {
    var existingURLs: Set<URL> = []
    var temporaryOutputURLs: [URL: URL] = [:]
    var moveError: Error?
    private(set) var movedPairs: [(source: URL, destination: URL)] = []
    private(set) var removedURLs: [URL] = []

    func fileExists(at url: URL) -> Bool {
        existingURLs.contains(url)
    }

    func makeTemporaryOutputURL(for destinationURL: URL) -> URL {
        if let temporaryOutputURL = temporaryOutputURLs[destinationURL] {
            return temporaryOutputURL
        }

        let fallback = destinationURL.deletingLastPathComponent().appendingPathComponent("temp-\(destinationURL.lastPathComponent)")
        temporaryOutputURLs[destinationURL] = fallback
        return fallback
    }

    func moveItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        movedPairs.append((sourceURL, destinationURL))
        if let moveError {
            throw moveError
        }
    }

    func removeItemIfPresent(at url: URL) {
        removedURLs.append(url)
    }
}
