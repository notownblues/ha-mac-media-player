import Foundation

/// Home Assistant MQTT Discovery configuration for hass-mqtt-mediaplayer
/// https://github.com/arctixdev/hass-mqtt-mediaplayer
struct HomeAssistantDiscoveryConfig: Encodable {
    let name: String
    let uniqueId: String
    let availability: Availability
    // State topics (individual topics per attribute)
    let stateStateTopic: String
    let stateTitleTopic: String
    let stateArtistTopic: String
    let stateAlbumTopic: String
    let stateDurationTopic: String
    let statePositionTopic: String
    let stateVolumeTopic: String
    let stateAlbumartTopic: String
    let stateMediatypeTopic: String
    // Command topics
    let commandVolumeTopic: String
    let commandPlayTopic: String
    let commandPlayPayload: String
    let commandPauseTopic: String
    let commandPausePayload: String
    let commandPlaypauseTopic: String
    let commandPlaypausePayload: String
    let commandNextTopic: String
    let commandNextPayload: String
    let commandPreviousTopic: String
    let commandPreviousPayload: String
    // Device info
    let device: Device

    struct Availability: Encodable {
        let topic: String
        let payloadAvailable: String
        let payloadNotAvailable: String

        enum CodingKeys: String, CodingKey {
            case topic
            case payloadAvailable = "payload_available"
            case payloadNotAvailable = "payload_not_available"
        }
    }

    struct Device: Encodable {
        let identifiers: [String]
        let name: String
        let model: String
        let manufacturer: String
        let swVersion: String

        enum CodingKeys: String, CodingKey {
            case identifiers
            case name
            case model
            case manufacturer
            case swVersion = "sw_version"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case uniqueId = "unique_id"
        case availability
        case stateStateTopic = "state_state_topic"
        case stateTitleTopic = "state_title_topic"
        case stateArtistTopic = "state_artist_topic"
        case stateAlbumTopic = "state_album_topic"
        case stateDurationTopic = "state_duration_topic"
        case statePositionTopic = "state_position_topic"
        case stateVolumeTopic = "state_volume_topic"
        case stateAlbumartTopic = "state_albumart_topic"
        case stateMediatypeTopic = "state_mediatype_topic"
        case commandVolumeTopic = "command_volume_topic"
        case commandPlayTopic = "command_play_topic"
        case commandPlayPayload = "command_play_payload"
        case commandPauseTopic = "command_pause_topic"
        case commandPausePayload = "command_pause_payload"
        case commandPlaypauseTopic = "command_playpause_topic"
        case commandPlaypausePayload = "command_playpause_payload"
        case commandNextTopic = "command_next_topic"
        case commandNextPayload = "command_next_payload"
        case commandPreviousTopic = "command_previous_topic"
        case commandPreviousPayload = "command_previous_payload"
        case device
    }

    // MARK: - Factory Method

    static func create(from config: MQTTConfiguration) -> HomeAssistantDiscoveryConfig {
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let base = config.baseTopic

        return HomeAssistantDiscoveryConfig(
            name: config.effectiveDeviceName,
            uniqueId: config.uniqueId,
            availability: Availability(
                topic: "\(base)/available",
                payloadAvailable: "online",
                payloadNotAvailable: "offline"
            ),
            // State topics
            stateStateTopic: "\(base)/state",
            stateTitleTopic: "\(base)/title",
            stateArtistTopic: "\(base)/artist",
            stateAlbumTopic: "\(base)/album",
            stateDurationTopic: "\(base)/duration",
            statePositionTopic: "\(base)/position",
            stateVolumeTopic: "\(base)/volume",
            stateAlbumartTopic: "\(base)/albumart",
            stateMediatypeTopic: "\(base)/mediatype",
            // Command topics
            commandVolumeTopic: "\(base)/set_volume",
            commandPlayTopic: "\(base)/command",
            commandPlayPayload: "play",
            commandPauseTopic: "\(base)/command",
            commandPausePayload: "pause",
            commandPlaypauseTopic: "\(base)/command",
            commandPlaypausePayload: "playpause",
            commandNextTopic: "\(base)/command",
            commandNextPayload: "next",
            commandPreviousTopic: "\(base)/command",
            commandPreviousPayload: "previous",
            // Device
            device: Device(
                identifiers: [config.uniqueId],
                name: config.effectiveDeviceName,
                model: getMacModel(),
                manufacturer: "Apple",
                swVersion: "macOS \(macOSVersion)"
            )
        )
    }

    /// Get Mac model identifier
    private static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    // MARK: - JSON Output

    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(self) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
