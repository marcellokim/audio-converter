import Foundation

enum FFmpegBinaryResolver {
    private static let helperRelativePath = "Contents/Helpers/ffmpeg"

    static func bundledBinaryURL(bundle: Bundle = .main, fileManager: FileManager = .default) -> URL? {
        let helperURL = bundle.bundleURL.appendingPathComponent(helperRelativePath)
        if fileManager.fileExists(atPath: helperURL.path) {
            return helperURL
        }

        return bundle.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "ffmpeg")
    }

    static func resolve(bundle: Bundle = .main, fileManager: FileManager = .default) -> StartupState {
        guard let url = bundledBinaryURL(bundle: bundle, fileManager: fileManager) else {
            return .startupError("Bundled ffmpeg binary is missing.")
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return .startupError("Bundled ffmpeg binary was not found at \(url.path).")
        }

        guard fileManager.isExecutableFile(atPath: url.path) else {
            return .startupError("Bundled ffmpeg binary is not executable.")
        }

        return .ready
    }
}
