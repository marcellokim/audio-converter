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
}
