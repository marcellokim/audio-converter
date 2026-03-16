import AVFoundation
import Foundation

protocol InputDurationProviding {
    func durationSeconds(for url: URL) -> Double?
}

struct InputDurationProvider: InputDurationProviding {
    func durationSeconds(for url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let seconds = asset.duration.seconds

        guard seconds.isFinite, seconds > 0 else {
            return nil
        }

        return seconds
    }
}
