import Foundation

enum FormatValidator {
    static func validate(outputFormat input: String) -> ValidationState {
        guard let format = FormatRegistry.format(for: input) else {
            return .invalidFormat(input)
        }

        return .valid(format)
    }
}
