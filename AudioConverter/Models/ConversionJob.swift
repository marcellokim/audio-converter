import Foundation

struct ConversionJob: Identifiable, Equatable {
    let id: UUID
    let inputFile: SelectedAudioFile
    let outputFormat: SupportedFormat
    let outputURL: URL
    let temporaryOutputURL: URL

    init(
        id: UUID = UUID(),
        inputFile: SelectedAudioFile,
        outputFormat: SupportedFormat,
        outputURL: URL,
        temporaryOutputURL: URL
    ) {
        self.id = id
        self.inputFile = inputFile
        self.outputFormat = outputFormat
        self.outputURL = outputURL
        self.temporaryOutputURL = temporaryOutputURL
    }
}
