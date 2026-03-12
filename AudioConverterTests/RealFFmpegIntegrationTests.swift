import Foundation
import XCTest
@testable import AudioConverter

final class RealFFmpegIntegrationTests: XCTestCase {
    func testVendoredFFmpegPassesStartupCheckAndConvertsWaveFixtureToMP3() throws {
        let ffmpegURL = try vendoredFFmpegURL()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: ffmpegURL.path))
        XCTAssertEqual(FFmpegStartupSelfCheck().validateCapabilities(for: ffmpegURL), .ready)

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let inputURL = tempDirectory.appendingPathComponent("fixture.wav")
        try Self.writeWaveFixture(to: inputURL)

        let format = try XCTUnwrap(FormatRegistry.format(for: "mp3"))
        let engine = ConversionEngine()
        let file = SelectedAudioFile(url: inputURL)

        let job: ConversionJob
        switch engine.makeJob(for: file, format: format) {
        case let .success(value):
            job = value
        case let .failure(state):
            XCTFail("Expected conversion job, got \(state)")
            return
        }

        let result = engine.run(job: job, ffmpegURL: ffmpegURL)
        XCTAssertEqual(result, .succeeded(outputURL: job.outputURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: job.outputURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: job.outputURL.path)
        let fileSize = try XCTUnwrap(attributes[.size] as? NSNumber)
        XCTAssertGreaterThan(fileSize.intValue, 0)

        let probeResult = try FFmpegRunner().run(
            ffmpegURL: ffmpegURL,
            arguments: ["-hide_banner", "-loglevel", "error", "-nostdin", "-i", job.outputURL.path, "-f", "null", "-"]
        )
        XCTAssertEqual(probeResult.terminationStatus, 0, probeResult.standardError)
    }

    private func vendoredFFmpegURL(filePath: StaticString = #filePath) throws -> URL {
        let testFileURL = URL(fileURLWithPath: "\(filePath)")
        let repositoryRootURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let ffmpegURL = repositoryRootURL
            .appendingPathComponent("AudioConverter", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("ffmpeg", isDirectory: true)
            .appendingPathComponent("ffmpeg", isDirectory: false)

        return try XCTUnwrap(
            FileManager.default.fileExists(atPath: ffmpegURL.path) ? ffmpegURL : nil,
            "Vendored ffmpeg binary is missing at \(ffmpegURL.path)."
        )
    }

    private static func writeWaveFixture(to url: URL) throws {
        let sampleRate = 44_100
        let durationSeconds = 1
        let sampleCount = sampleRate * durationSeconds
        let bytesPerSample = 2
        let channelCount = 1
        let bitsPerSample = 16

        var pcmData = Data(capacity: sampleCount * bytesPerSample)
        for index in 0 ..< sampleCount {
            let sample = sin(2 * Double.pi * 440 * Double(index) / Double(sampleRate))
            let amplitude = Int16(max(-32_767, min(32_767, Int(sample * 12_000))))
            var littleEndian = amplitude.littleEndian
            pcmData.append(Data(bytes: &littleEndian, count: MemoryLayout<Int16>.size))
        }

        let byteRate = sampleRate * channelCount * bytesPerSample
        let blockAlign = channelCount * bytesPerSample
        let chunkSize = 36 + pcmData.count

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: UInt32(chunkSize).littleEndianBytes)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt16(channelCount).littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: UInt32(byteRate).littleEndianBytes)
        data.append(contentsOf: UInt16(blockAlign).littleEndianBytes)
        data.append(contentsOf: UInt16(bitsPerSample).littleEndianBytes)
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: UInt32(pcmData.count).littleEndianBytes)
        data.append(pcmData)

        try data.write(to: url, options: .atomic)
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: littleEndian, Array.init)
    }
}
