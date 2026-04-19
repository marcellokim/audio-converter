import Foundation

protocol FileManaging {
    func fileExists(at url: URL) -> Bool
    func makeTemporaryOutputURL(for destinationURL: URL) -> URL
    func moveItemAtomically(at sourceURL: URL, to destinationURL: URL) throws
    func replaceItemAtomically(at sourceURL: URL, to destinationURL: URL) throws
    func removeItemIfPresent(at url: URL)
}
