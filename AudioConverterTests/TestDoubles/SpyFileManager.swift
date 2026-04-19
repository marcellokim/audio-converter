import Foundation
@testable import AudioConverter

final class SpyFileManager: FileManaging {
    var existingPaths: Set<String> = []
    var temporaryOutputURL = URL(fileURLWithPath: "/tmp/render.partial.mp3")
    var movedItems: [(URL, URL)] = []
    var replacedItems: [(URL, URL)] = []
    var removedItems: [URL] = []
    var moveError: Error?
    var replaceError: Error?

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
        existingPaths.remove(sourceURL.path)
        existingPaths.insert(destinationURL.path)
    }

    func replaceItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        if let replaceError {
            throw replaceError
        }

        if existingPaths.contains(destinationURL.path) {
            replacedItems.append((sourceURL, destinationURL))
        } else {
            movedItems.append((sourceURL, destinationURL))
        }

        existingPaths.remove(sourceURL.path)
        existingPaths.insert(destinationURL.path)
    }

    func removeItemIfPresent(at url: URL) {
        removedItems.append(url)
    }
}
