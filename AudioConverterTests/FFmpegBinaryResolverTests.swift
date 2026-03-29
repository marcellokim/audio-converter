import Foundation
import XCTest
@testable import AudioConverter

final class FFmpegBinaryResolverTests: XCTestCase {
    func testBundledBinaryURLPrefersHelperLocation() throws {
        let fixture = try BundleFixture()
        defer { fixture.cleanup() }
        let helperURL = try fixture.makeHelperBinary()
        _ = try fixture.makeLegacyResourceBinary()

        let resolvedURL = FFmpegBinaryResolver.bundledBinaryURL(bundle: fixture.bundle)

        XCTAssertEqual(resolvedURL, helperURL)
    }

    func testResolveFallsBackToLegacyResourceLocation() throws {
        let fixture = try BundleFixture()
        defer { fixture.cleanup() }
        let legacyURL = try fixture.makeLegacyResourceBinary()

        XCTAssertEqual(FFmpegBinaryResolver.bundledBinaryURL(bundle: fixture.bundle), legacyURL)
        XCTAssertEqual(FFmpegBinaryResolver.resolve(bundle: fixture.bundle), .ready)
    }

    func testResolveReturnsStartupErrorWhenNoBundledBinaryExists() throws {
        let fixture = try BundleFixture()
        defer { fixture.cleanup() }

        XCTAssertEqual(
            FFmpegBinaryResolver.resolve(bundle: fixture.bundle),
            .startupError("Bundled ffmpeg binary is missing.")
        )
    }
}

private struct BundleFixture {
    let bundleURL: URL
    let bundle: Bundle

    init() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let bundleURL = rootURL.appendingPathComponent("Fixture.app", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)

        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let infoPlist: NSDictionary = [
            "CFBundleIdentifier": "com.example.Fixture",
            "CFBundleName": "Fixture",
            "CFBundlePackageType": "APPL"
        ]
        guard infoPlist.write(to: infoPlistURL, atomically: true) else {
            throw CocoaError(.fileWriteUnknown)
        }

        guard let bundle = Bundle(url: bundleURL) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.bundleURL = bundleURL
        self.bundle = bundle
    }

    func makeHelperBinary() throws -> URL {
        let helperURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("ffmpeg", isDirectory: false)

        try writeExecutable(at: helperURL)
        return helperURL
    }

    func makeLegacyResourceBinary() throws -> URL {
        let resourceURL = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("ffmpeg", isDirectory: true)
            .appendingPathComponent("ffmpeg", isDirectory: false)

        try writeExecutable(at: resourceURL)
        return resourceURL
    }

    private func writeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("echo ok".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
    }
}
