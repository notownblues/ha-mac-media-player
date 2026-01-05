import Foundation

/// Async wrapper for running external processes with stdout streaming
final class ProcessRunner {
    enum ProcessError: LocalizedError {
        case binaryNotFound(paths: [String])
        case executionFailed(code: Int32, error: String)
        case terminated

        var errorDescription: String? {
            switch self {
            case .binaryNotFound(let paths):
                return "Binary not found. Searched: \(paths.joined(separator: ", "))"
            case .executionFailed(let code, let error):
                return "Process exited with code \(code): \(error)"
            case .terminated:
                return "Process was terminated"
            }
        }
    }

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    /// Find the executable path from a list of possible locations
    static func findExecutable(paths: [String]) -> String? {
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Run a command and stream stdout lines via AsyncStream
    func stream(
        executable: String,
        arguments: [String] = []
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            self.process = process
            self.outputPipe = outputPipe
            self.errorPipe = errorPipe

            // Buffer for accumulating partial lines
            var lineBuffer = ""
            let bufferLock = NSLock()

            // Handle stdout data - buffer until we have complete lines
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    return
                }

                guard let chunk = String(data: data, encoding: .utf8) else {
                    return
                }

                bufferLock.lock()
                lineBuffer += chunk

                // Process complete lines (ending with newline)
                while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
                    let line = String(lineBuffer[..<newlineIndex])
                    lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

                    if !line.isEmpty {
                        bufferLock.unlock()
                        continuation.yield(line)
                        bufferLock.lock()
                    }
                }
                bufferLock.unlock()
            }

            // Handle process termination
            process.terminationHandler = { [weak self] proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil

                // Process any remaining data in buffer
                bufferLock.lock()
                if !lineBuffer.isEmpty {
                    let remaining = lineBuffer
                    lineBuffer = ""
                    bufferLock.unlock()
                    continuation.yield(remaining)
                } else {
                    bufferLock.unlock()
                }

                self?.process = nil
                self?.outputPipe = nil
                self?.errorPipe = nil

                if proc.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.finish(throwing: ProcessError.executionFailed(
                        code: proc.terminationStatus,
                        error: errorString
                    ))
                } else {
                    continuation.finish()
                }
            }

            // Handle stream cancellation
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.terminate()
            }

            // Start the process
            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    /// Run a command and return all output at once
    func run(
        executable: String,
        arguments: [String] = []
    ) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if proc.terminationStatus == 0 {
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } else {
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: ProcessError.executionFailed(
                        code: proc.terminationStatus,
                        error: errorString
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Terminate the running process
    func terminate() {
        process?.terminate()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        errorPipe = nil
    }

    /// Check if a process is currently running
    var isRunning: Bool {
        process?.isRunning ?? false
    }

    deinit {
        terminate()
    }
}
