import Foundation

final class AppState: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var outputFormat: String = "mp3"
    @Published var statusMessage: String = "Select audio files and choose an output format."
    @Published var startupError: String?

    var canStartConversion: Bool {
        startupError == nil && !selectedFiles.isEmpty && !outputFormat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
