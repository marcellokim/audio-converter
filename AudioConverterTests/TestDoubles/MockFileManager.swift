import Foundation
@testable import AudioConverter

final class MockFileManager: FileManaging {
    private let lock = NSLock()

    var existingURLs: Set<URL> = []
    var temporaryOutputURLs: [URL: URL] = [:]
    var moveError: Error?
    var replaceError: Error?
    private(set) var movedPairs: [(source: URL, destination: URL)] = []
    private(set) var replacedPairs: [(source: URL, destination: URL)] = []
    private(set) var removedURLs: [URL] = []

    func fileExists(at url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return existingURLs.contains(url)
    }

    func makeTemporaryOutputURL(for destinationURL: URL) -> URL {
        lock.lock()
        defer { lock.unlock() }

        if let temporaryOutputURL = temporaryOutputURLs[destinationURL] {
            return temporaryOutputURL
        }

        let fallback = destinationURL.deletingLastPathComponent().appendingPathComponent("temp-\(destinationURL.lastPathComponent)")
        temporaryOutputURLs[destinationURL] = fallback
        return fallback
    }

    func moveItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        movedPairs.append((sourceURL, destinationURL))
        if let moveError {
            throw moveError
        }

        existingURLs.remove(sourceURL)
        existingURLs.insert(destinationURL)
    }

    func replaceItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }

        if let replaceError {
            throw replaceError
        }

        if existingURLs.contains(destinationURL) {
            replacedPairs.append((sourceURL, destinationURL))
        } else {
            movedPairs.append((sourceURL, destinationURL))
        }

        existingURLs.remove(sourceURL)
        existingURLs.insert(destinationURL)
    }

    func removeItemIfPresent(at url: URL) {
        lock.lock()
        defer { lock.unlock() }

        removedURLs.append(url)
    }
}
