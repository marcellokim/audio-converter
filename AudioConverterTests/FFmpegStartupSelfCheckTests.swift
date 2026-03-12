import Foundation
import XCTest
@testable import AudioConverter

final class FFmpegStartupSelfCheckTests: XCTestCase {
    func testValidateCapabilitiesRunsExpectedCommandsInOrder() throws {
        let fixture = try FakeFFmpegFixture(
            versionOutput: "ffmpeg version 8.0",
            encodersOutput: Self.fullEncoderOutput,
            muxersOutput: Self.fullMuxerOutput
        )

        let result = FFmpegStartupSelfCheck().validateCapabilities(for: fixture.scriptURL)

        XCTAssertEqual(result, .ready)
        XCTAssertEqual(try fixture.recordedCommands(), [
            "-hide_banner -version",
            "-hide_banner -encoders",
            "-hide_banner -muxers"
        ])
    }

    func testValidateCapabilitiesUsesLowercasedExactTokenMatch() throws {
        let fixture = try FakeFFmpegFixture(
            versionOutput: "ffmpeg version 8.0",
            encodersOutput: "A..... LIBMP3LAME\nA..... AAC\nA..... PCM_S16LE\nA..... FLAC\nA..... PCM_S16BE\nA..... LIBOPUS\nA..... LIBVORBIS\n",
            muxersOutput: "E mp3\nE IPOD\nE adts\nE wav\nE flac\nE aiff\nE opus\nE ogg\n"
        )

        let result = FFmpegStartupSelfCheck().validateCapabilities(for: fixture.scriptURL)

        XCTAssertEqual(result, .ready)
    }

    func testValidateCapabilitiesFailsWhenRequiredCapabilityMissingByExactToken() throws {
        let fixture = try FakeFFmpegFixture(
            versionOutput: "ffmpeg version 8.0",
            encodersOutput: "A..... libmp3lame_alias\nA..... aac\nA..... pcm_s16le\nA..... flac\nA..... pcm_s16be\nA..... libopus\nA..... libvorbis\n",
            muxersOutput: Self.fullMuxerOutput
        )

        let result = FFmpegStartupSelfCheck().validateCapabilities(for: fixture.scriptURL)

        guard case let .startupError(message) = result else {
            return XCTFail("Expected startupError, got \(result)")
        }

        XCTAssertTrue(message.contains("libmp3lame"))
    }

    private static let fullEncoderOutput = """
A..... libmp3lame
A..... aac
A..... pcm_s16le
A..... flac
A..... pcm_s16be
A..... libopus
A..... libvorbis
"""

    private static let fullMuxerOutput = """
E mp3
E ipod
E adts
E wav
E flac
E aiff
E opus
E ogg
"""
}

private struct FakeFFmpegFixture {
    let scriptURL: URL
    private let commandsLogURL: URL
    private let tempDirectoryURL: URL

    init(versionOutput: String, encodersOutput: String, muxersOutput: String) throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        commandsLogURL = tempDirectoryURL.appendingPathComponent("commands.log")
        scriptURL = tempDirectoryURL.appendingPathComponent("fake-ffmpeg.sh")

        let script = """
        #!/bin/sh
        echo "$*" >> "\(commandsLogURL.path)"
        case "$2" in
          -version)
            cat <<'EOF'
        \(versionOutput)
        EOF
            ;;
          -encoders)
            cat <<'EOF'
        \(encodersOutput)
        EOF
            ;;
          -muxers)
            cat <<'EOF'
        \(muxersOutput)
        EOF
            ;;
          *)
            echo "unexpected args: $*" >&2
            exit 1
            ;;
        esac
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    func recordedCommands() throws -> [String] {
        guard FileManager.default.fileExists(atPath: commandsLogURL.path) else {
            return []
        }

        return try String(contentsOf: commandsLogURL)
            .split(separator: "\n")
            .map(String.init)
    }
}
