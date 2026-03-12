import Foundation

protocol CapabilityChecking {
    func validateCapabilities(for ffmpegURL: URL) -> StartupState
}
