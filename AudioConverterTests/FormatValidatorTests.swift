import XCTest
@testable import AudioConverter

final class FormatValidatorTests: XCTestCase {
    func testValidateReturnsNormalizedSupportedFormat() {
        let result = FormatValidator.validate(outputFormat: " .MP3 ")

        guard case let .valid(format) = result else {
            return XCTFail("Expected valid format")
        }

        XCTAssertEqual(format.id, "mp3")
        XCTAssertEqual(format.outputExtension, "mp3")
    }

    func testValidateAcceptsTrimmedLowercasedFormat() {
        let result = FormatValidator.validate(outputFormat: " flac ")

        guard case let .valid(format) = result else {
            return XCTFail("Expected valid format")
        }

        XCTAssertEqual(format.id, "flac")
    }

    func testValidateReturnsInvalidFormatForUnknownValue() {
        let result = FormatValidator.validate(outputFormat: "abc")

        XCTAssertEqual(result, .invalidFormat("abc"))
    }
}
