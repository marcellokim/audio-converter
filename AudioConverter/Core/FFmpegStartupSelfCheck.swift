import Foundation

struct FFmpegStartupSelfCheck: CapabilityChecking {
    func validateCapabilities(for ffmpegURL: URL) -> StartupState {
        do {
            _ = try runFFmpeg(arguments: ["-hide_banner", "-version"], ffmpegURL: ffmpegURL)
            let encodersOutput = try runFFmpeg(arguments: ["-hide_banner", "-encoders"], ffmpegURL: ffmpegURL)
            let muxersOutput = try runFFmpeg(arguments: ["-hide_banner", "-muxers"], ffmpegURL: ffmpegURL)

            let encoders = parseCapabilityTokens(from: encodersOutput)
            let muxers = parseCapabilityTokens(from: muxersOutput)

            let missingEncoders = FormatRegistry.requiredEncoderKeys.subtracting(encoders).sorted()
            if !missingEncoders.isEmpty {
                return .startupError("Missing required ffmpeg encoders: \(missingEncoders.joined(separator: ", ")).")
            }

            let missingMuxers = FormatRegistry.requiredMuxerKeys.subtracting(muxers).sorted()
            if !missingMuxers.isEmpty {
                return .startupError("Missing required ffmpeg muxers: \(missingMuxers.joined(separator: ", ")).")
            }

            return .ready
        } catch {
            return .startupError(error.localizedDescription)
        }
    }

    private func runFFmpeg(arguments: [String], ffmpegURL: URL) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputLock = NSLock()
        let errorLock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()

        process.executableURL = ffmpegURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            outputLock.lock()
            stdoutData.append(data)
            outputLock.unlock()
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            errorLock.lock()
            stderrData.append(data)
            errorLock.unlock()
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        outputLock.lock()
        stdoutData.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        outputLock.unlock()

        errorLock.lock()
        stderrData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        errorLock.unlock()

        let combined = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "FFmpegStartupSelfCheck",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: combined.isEmpty ? "ffmpeg self-check failed." : combined]
            )
        }

        return combined
    }

    private func parseCapabilityTokens(from output: String) -> Set<String> {
        Set(
            output
                .split(separator: "\n")
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return nil }
                    let parts = trimmed.split(whereSeparator: \ .isWhitespace)
                    guard parts.count >= 2 else { return nil }
                    let token = String(parts[1]).lowercased()
                    guard token.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil else {
                        return nil
                    }
                    return token
                }
        )
    }
}
