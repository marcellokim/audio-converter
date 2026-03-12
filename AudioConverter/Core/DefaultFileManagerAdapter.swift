import Foundation

struct DefaultFileManagerAdapter: FileManaging {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func makeTemporaryOutputURL(for destinationURL: URL) -> URL {
        let directoryURL = destinationURL.deletingLastPathComponent()
        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let ext = destinationURL.pathExtension
        return directoryURL.appendingPathComponent(".\(baseName).\(UUID().uuidString).partial.\(ext)")
    }

    func moveItemAtomically(at sourceURL: URL, to destinationURL: URL) throws {
        if fileExists(at: destinationURL) {
            throw CocoaError(.fileWriteFileExists)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    func removeItemIfPresent(at url: URL) {
        guard fileExists(at: url) else { return }
        try? fileManager.removeItem(at: url)
    }
}
