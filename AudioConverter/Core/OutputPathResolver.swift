import Foundation

enum OutputPathResolver {
    static func resolveDestination(for inputURL: URL, format: SupportedFormat) -> Result<URL, SkipReason> {
        let inputExtension = inputURL.pathExtension.lowercased()
        let outputExtension = format.outputExtension.lowercased()

        guard inputExtension != outputExtension else {
            return .failure(.sameFormat)
        }

        let destinationURL = inputURL
            .deletingPathExtension()
            .appendingPathExtension(outputExtension)

        return .success(destinationURL)
    }
}
