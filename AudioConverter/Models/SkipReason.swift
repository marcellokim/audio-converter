import Foundation

enum SkipReason: Error, Equatable {
    case sameFormat
    case conflictExistingOutput

    var title: String {
        switch self {
        case .sameFormat:
            return "Same format"
        case .conflictExistingOutput:
            return "Existing output"
        }
    }

    var message: String {
        switch self {
        case .sameFormat:
            return "Input and output formats match, so the file was skipped."
        case .conflictExistingOutput:
            return "A file already exists at the destination path, so overwrite was avoided."
        }
    }
}
