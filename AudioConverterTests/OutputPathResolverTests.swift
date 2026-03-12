import Foundation
import XCTest
@testable import AudioConverter

final class OutputPathResolverTests: XCTestCase {
    func testResolveDestinationKeepsSameFolderAndBasename() throws {
        let inputURL = URL(fileURLWithPath: "/tmp/session/take01.wav")
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let result = OutputPathResolver.resolveDestination(for: inputURL, format: format)

        XCTAssertEqual(try result.get(), URL(fileURLWithPath: "/tmp/session/take01.mp3"))
    }

    func testResolveDestinationSupportsUnicodePaths() throws {
        let inputURL = URL(fileURLWithPath: "/tmp/믹스/🎧 demo.aiff")
        let format = try XCTUnwrap(FormatRegistry.format(for: "flac"))

        let result = OutputPathResolver.resolveDestination(for: inputURL, format: format)

        XCTAssertEqual(try result.get(), URL(fileURLWithPath: "/tmp/믹스/🎧 demo.flac"))
    }

    func testResolveDestinationSkipsSameFormatIgnoringCase() throws {
        let inputURL = URL(fileURLWithPath: "/tmp/stem.MP3")
        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))

        let result = OutputPathResolver.resolveDestination(for: inputURL, format: format)

        XCTAssertEqual(result, .failure(.sameFormat))
    }
}
