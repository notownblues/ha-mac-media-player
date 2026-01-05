import Foundation

/// Service for executing media player commands
@MainActor
final class CommandExecutor {
    // MARK: - Dependencies

    private let volumeService: VolumeService
    private var mediaControlPath: String?

    // MARK: - Initialization

    init(volumeService: VolumeService) {
        self.volumeService = volumeService
        self.mediaControlPath = ProcessRunner.findExecutable(paths: Constants.MediaControl.binaryPaths)
    }

    // MARK: - Command Execution

    /// Execute a player command
    func execute(command: PlayerCommand, value: Any? = nil) async -> CommandResponse {
        Logger.info("Executing command: \(command.rawValue)", log: Logger.homeAssistant)

        if command.isVolumeCommand {
            return executeVolumeCommand(command, value: value)
        } else {
            return await executeMediaCommand(command)
        }
    }

    // MARK: - Volume Commands

    private func executeVolumeCommand(_ command: PlayerCommand, value: Any?) -> CommandResponse {
        switch command {
        case .volumeSet:
            if let level = value as? Double {
                volumeService.setVolume(Float(level))
                return .success(command)
            } else if let level = value as? Float {
                volumeService.setVolume(level)
                return .success(command)
            } else {
                return .failure(command, error: "Invalid volume level")
            }

        case .volumeUp:
            volumeService.increaseVolume()
            return .success(command)

        case .volumeDown:
            volumeService.decreaseVolume()
            return .success(command)

        case .volumeMute:
            volumeService.toggleMute()
            return .success(command)

        default:
            return .failure(command, error: "Unknown volume command")
        }
    }

    // MARK: - Media Commands

    private func executeMediaCommand(_ command: PlayerCommand) async -> CommandResponse {
        guard let path = mediaControlPath else {
            return .failure(command, error: "media-control not found")
        }

        guard let mediaCommand = command.mediaControlCommand else {
            return .failure(command, error: "No media-control mapping for \(command.rawValue)")
        }

        do {
            let runner = ProcessRunner()
            _ = try await runner.run(executable: path, arguments: [mediaCommand])
            return .success(command)
        } catch {
            return .failure(command, error: error.localizedDescription)
        }
    }
}
