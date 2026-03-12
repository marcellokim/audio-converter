import Foundation
@testable import AudioConverter

struct StubCapabilityChecker: CapabilityChecking {
    let result: StartupState

    func validateCapabilities(for ffmpegURL: URL) -> StartupState {
        result
    }
}
