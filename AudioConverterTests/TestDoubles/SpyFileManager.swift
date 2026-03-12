import Foundation
@testable import AudioConverter

final class SpyFileManager: FileManaging {
    var existingPaths: Set<String> = []
    var temporaryOutputURL = URL(fileURLWithPath: "/tmp/render.partial.mp3")
    var movedItems: [(URL, URL)] = []
    var removedItems: [URL] = []
    var moveError: Error?

    func fileExists(at url: URL) -> Bool {
        existingPaths.contains(url.path)
    }

    func makeTemporaryOutputURL(for destinationURL: URL) -> URL {
        temporaryOutputURL
    }

    func moveItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        if let moveError {
            throw moveError
        }

        movedItems.append((sourceURL, destinationURL))
    }

    func removeItemIfPresent(at url: URL) {
        removedItems.append(url)
    }
}
