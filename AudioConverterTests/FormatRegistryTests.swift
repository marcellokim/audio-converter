import XCTest
@testable import AudioConverter

final class FormatRegistryTests: XCTestCase {
    func testRegistryContainsExpectedFormatsAndFields() {
        let formats = Dictionary(uniqueKeysWithValues: FormatRegistry.allFormats.map { ($0.id, $0) })

        XCTAssertEqual(Set(formats.keys), ["aac", "aiff", "flac", "m4a", "mp3", "ogg", "opus", "wav"])
        XCTAssertEqual(formats["mp3"]?.requiredEncoderKey, "libmp3lame")
        XCTAssertEqual(formats["mp3"]?.requiredMuxerKey, "mp3")
        XCTAssertEqual(formats["mp3"]?.ffmpegArgs, ["-vn", "-c:a", "libmp3lame", "-q:a", "2"])
        XCTAssertEqual(formats["m4a"]?.requiredMuxerKey, "ipod")
        XCTAssertEqual(formats["aac"]?.requiredMuxerKey, "adts")
        XCTAssertEqual(formats["wav"]?.requiredEncoderKey, "pcm_s16le")
        XCTAssertEqual(formats["flac"]?.requiredMuxerKey, "flac")
        XCTAssertEqual(formats["aiff"]?.requiredEncoderKey, "pcm_s16be")
        XCTAssertEqual(formats["opus"]?.requiredEncoderKey, "libopus")
        XCTAssertEqual(formats["ogg"]?.requiredEncoderKey, "libvorbis")
    }

    func testRequiredCapabilitiesAreDerivedFromRegistry() {
        let expectedEncoders = Set(FormatRegistry.allFormats.map { $0.requiredEncoderKey.lowercased() })
        let expectedMuxers = Set(FormatRegistry.allFormats.map { $0.requiredMuxerKey.lowercased() })

        XCTAssertEqual(FormatRegistry.requiredEncoderKeys, expectedEncoders)
        XCTAssertEqual(FormatRegistry.requiredMuxerKeys, expectedMuxers)
    }

    func testNormalizedKeyTrimsWhitespaceDotsAndLowercases() {
        XCTAssertEqual(FormatRegistry.normalizedKey(for: " .MP3 \n"), "mp3")
        XCTAssertEqual(FormatRegistry.normalizedKey(for: " flac "), "flac")
    }
}
