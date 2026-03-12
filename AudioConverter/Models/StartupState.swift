import Foundation

enum StartupState: Equatable {
    case idle
    case checking
    case ready
    case startupError(String)
}
