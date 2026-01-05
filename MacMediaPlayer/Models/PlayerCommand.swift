import Foundation

/// Commands received from Home Assistant
enum PlayerCommand: String, CaseIterable {
    case play = "media_play"
    case pause = "media_pause"
    case playPause = "media_play_pause"
    case stop = "media_stop"
    case nextTrack = "media_next_track"
    case previousTrack = "media_previous_track"
    case volumeSet = "volume_set"
    case volumeUp = "volume_up"
    case volumeDown = "volume_down"
    case volumeMute = "volume_mute"

    /// Parse command from JSON payload
    static func parse(from jsonString: String) -> (command: PlayerCommand, value: Any?)? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try parsing as simple command string
            return PlayerCommand(rawValue: jsonString).map { ($0, nil) }
        }

        // Check for volume_set with value
        if let volumeLevel = json["volume_level"] as? Double {
            return (.volumeSet, volumeLevel)
        }

        // Check for command key
        if let commandStr = json["command"] as? String,
           let command = PlayerCommand(rawValue: commandStr) {
            return (command, json["value"])
        }

        // Try each known command key
        for command in PlayerCommand.allCases {
            if json[command.rawValue] != nil {
                return (command, json[command.rawValue])
            }
        }

        return nil
    }

    /// The corresponding media-control CLI command
    var mediaControlCommand: String? {
        switch self {
        case .play:
            return "play"
        case .pause:
            return "pause"
        case .playPause:
            return "toggle-play-pause"
        case .stop:
            return "pause"  // media-control doesn't have stop, use pause
        case .nextTrack:
            return "next"
        case .previousTrack:
            return "previous"
        case .volumeSet, .volumeUp, .volumeDown, .volumeMute:
            return nil  // Volume handled by VolumeService
        }
    }

    /// Whether this command affects volume
    var isVolumeCommand: Bool {
        switch self {
        case .volumeSet, .volumeUp, .volumeDown, .volumeMute:
            return true
        default:
            return false
        }
    }

    /// Whether this command affects media playback
    var isMediaCommand: Bool {
        !isVolumeCommand
    }
}

// MARK: - Command Response
struct CommandResponse {
    let command: PlayerCommand
    let success: Bool
    let error: String?

    static func success(_ command: PlayerCommand) -> CommandResponse {
        CommandResponse(command: command, success: true, error: nil)
    }

    static func failure(_ command: PlayerCommand, error: String) -> CommandResponse {
        CommandResponse(command: command, success: false, error: error)
    }
}
