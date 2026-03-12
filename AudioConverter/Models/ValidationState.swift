import Foundation

enum ValidationState: Equatable {
    case idle
    case valid(SupportedFormat)
    case invalidFormat(String)
}
