import Foundation
import XCTest
@testable import AudioConverter

final class FFmpegCommandBuilderTests: XCTestCase {
    func testMakeArgumentsIncludesSafetyFlagsAndRegistryArgs() throws {
        let inputURL = URL(fileURLWithPath: "/tmp/input.wav")
        let outputURL = URL(fileURLWithPath: "/tmp/output.mp3")
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let arguments = FFmpegCommandBuilder.makeArguments(
            inputURL: inputURL,
            outputURL: outputURL,
            outputFormat: format
        )

        XCTAssertEqual(
            arguments.prefix(8),
            ["-hide_banner", "-loglevel", "error", "-nostdin", "-nostats", "-progress", "pipe:1", "-n"]
        )
        XCTAssertEqual(arguments.suffix(6), ["-vn", "-c:a", "libmp3lame", "-q:a", "2", outputURL.path])
        XCTAssertTrue(arguments.contains(inputURL.path))
    }

    func testMakeMergeArgumentsPreservesInputOrderAndBuildsConcatFilterGraph() throws {
        let inputURLs = [
            URL(fileURLWithPath: "/tmp/intro.wav"),
            URL(fileURLWithPath: "/tmp/verse.aiff")
        ]
        let outputURL = URL(fileURLWithPath: "/tmp/merged.mp3")
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let arguments = FFmpegCommandBuilder.makeMergeArguments(
            inputURLs: inputURLs,
            outputURL: outputURL,
            outputFormat: format
        )

        XCTAssertEqual(
            Array(arguments.prefix(8)),
            ["-hide_banner", "-loglevel", "error", "-nostdin", "-nostats", "-progress", "pipe:1", "-n"]
        )
        XCTAssertEqual(arguments[8...11], ["-i", inputURLs[0].path, "-i", inputURLs[1].path])
        XCTAssertTrue(arguments.contains("-filter_complex"))
        XCTAssertTrue(arguments.contains("[0:a:0]aresample=async=1:first_pts=0,aformat=sample_rates=44100:sample_fmts=fltp:channel_layouts=stereo[a0];[1:a:0]aresample=async=1:first_pts=0,aformat=sample_rates=44100:sample_fmts=fltp:channel_layouts=stereo[a1];[a0][a1]concat=n=2:v=0:a=1[merged]"))
        XCTAssertTrue(arguments.contains("[merged]"))
        XCTAssertEqual(
            Array(arguments.suffix(12)),
            ["-map", "[merged]", "-ac", "2", "-ar", "44100", "-vn", "-c:a", "libmp3lame", "-q:a", "2", outputURL.path]
        )
    }
}
