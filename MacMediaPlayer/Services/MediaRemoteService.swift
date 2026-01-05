import Foundation
import Combine

/// Service that interfaces with media-control CLI to get Now Playing information
@MainActor
final class MediaRemoteService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentState: MediaState = .idle
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var error: Error?
    @Published private(set) var binaryPath: String?

    // MARK: - Private Properties

    private var processRunner: ProcessRunner?
    private var streamTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private let restartDelay: TimeInterval = 2.0

    // MARK: - Initialization

    init() {
        // Find the media-control binary
        binaryPath = ProcessRunner.findExecutable(paths: Constants.MediaControl.binaryPaths)
    }

    // MARK: - Public Methods

    /// Check if media-control is available
    var isAvailable: Bool {
        binaryPath != nil
    }

    /// Start streaming Now Playing updates
    func start() {
        guard let path = binaryPath else {
            Logger.error("media-control binary not found", log: Logger.media)
            print("[MediaRemote] ERROR: media-control binary not found at expected paths")
            error = MediaRemoteError.binaryNotFound
            return
        }

        guard !isRunning else { return }

        Logger.info("Starting media-control stream", log: Logger.media)
        print("[MediaRemote] Starting media-control stream from: \(path)")

        let runner = ProcessRunner()
        self.processRunner = runner
        self.isRunning = true
        self.error = nil

        streamTask = Task { [weak self] in
            do {
                let stream = runner.stream(
                    executable: path,
                    arguments: ["stream", "--no-diff"]
                )

                print("[MediaRemote] Stream started, waiting for output...")

                for try await line in stream {
                    await self?.handleOutput(line)
                }

                // Stream ended normally
                print("[MediaRemote] Stream ended normally")
                await self?.handleStreamEnded(error: nil)
            } catch {
                print("[MediaRemote] Stream error: \(error)")
                await self?.handleStreamEnded(error: error)
            }
        }
    }

    /// Stop streaming
    func stop() {
        Logger.info("Stopping media-control stream", log: Logger.media)

        streamTask?.cancel()
        streamTask = nil

        restartTask?.cancel()
        restartTask = nil

        processRunner?.terminate()
        processRunner = nil

        isRunning = false
        currentState = .idle
    }

    /// Restart the stream
    func restart() {
        stop()
        start()
    }

    // MARK: - Private Methods

    private func handleOutput(_ line: String) {
        guard !line.isEmpty else { return }

        // Parse JSON output from media-control
        guard let data = line.data(using: .utf8) else {
            Logger.warning("Failed to convert line to data", log: Logger.media)
            print("[MediaRemote] Failed to convert line to UTF-8 data")
            return
        }

        Logger.debug("Received media-control output: \(String(line.prefix(200)))...", log: Logger.media)
        print("[MediaRemote] Received JSON line (\(line.count) chars)")

        do {
            let decoder = JSONDecoder()
            let output = try decoder.decode(MediaControlOutput.self, from: data)
            let newState = MediaState(from: output)

            print("[MediaRemote] Parsed: title=\(newState.title ?? "nil"), artist=\(newState.artist ?? "nil"), playing=\(newState.isPlaying), state=\(newState.state.rawValue)")
            Logger.info("Parsed media state: title=\(newState.title ?? "nil"), artist=\(newState.artist ?? "nil"), playing=\(newState.isPlaying)", log: Logger.media)

            // Only update if state changed
            if newState != currentState {
                currentState = newState
                print("[MediaRemote] State updated to: \(newState.state.rawValue)")
                Logger.mediaStateChanged(
                    title: newState.title,
                    artist: newState.artist,
                    state: newState.state.rawValue
                )
            }
        } catch {
            Logger.error("Failed to parse media-control output: \(error)", log: Logger.media)
            print("[MediaRemote] JSON PARSE ERROR: \(error)")
            print("[MediaRemote] Raw line: \(String(line.prefix(500)))")
        }
    }

    private func handleStreamEnded(error: Error?) {
        isRunning = false

        if let error = error {
            Logger.error("media-control stream error: \(error)", log: Logger.media)
            self.error = error

            // Schedule restart
            scheduleRestart()
        } else {
            Logger.info("media-control stream ended", log: Logger.media)
        }

        currentState = .idle
    }

    private func scheduleRestart() {
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            guard let self = self else { return }

            Logger.info("Scheduling media-control restart in \(self.restartDelay)s", log: Logger.media)

            try? await Task.sleep(nanoseconds: UInt64(self.restartDelay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.start()
            }
        }
    }
}

// MARK: - Errors

enum MediaRemoteError: LocalizedError {
    case binaryNotFound
    case streamFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "media-control not found. Install with: brew tap ungive/media-control && brew install media-control"
        case .streamFailed(let reason):
            return "Media stream failed: \(reason)"
        }
    }

    var installInstructions: String {
        """
        Install media-control via Homebrew:

        brew tap ungive/media-control
        brew install media-control
        """
    }
}
