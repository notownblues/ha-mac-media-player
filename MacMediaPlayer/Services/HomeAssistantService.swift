import Foundation
import Combine

/// Service that handles Home Assistant MQTT discovery and state publishing
@MainActor
final class HomeAssistantService: ObservableObject {
    // MARK: - Dependencies

    private let mqttService: MQTTService
    private let mediaRemoteService: MediaRemoteService
    private let volumeService: VolumeService
    private let commandExecutor: CommandExecutor

    // MARK: - Configuration

    private var config: MQTTConfiguration

    // MARK: - State

    @Published private(set) var isDiscoveryPublished: Bool = false
    @Published private(set) var lastPublishedState: Date?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var statePublishTask: Task<Void, Never>?
    private let statePublishDebounce: TimeInterval = 0.1  // 100ms debounce

    // MARK: - Initialization

    init(
        mqttService: MQTTService,
        mediaRemoteService: MediaRemoteService,
        volumeService: VolumeService,
        commandExecutor: CommandExecutor,
        config: MQTTConfiguration
    ) {
        self.mqttService = mqttService
        self.mediaRemoteService = mediaRemoteService
        self.volumeService = volumeService
        self.commandExecutor = commandExecutor
        self.config = config

        setupBindings()
    }

    // MARK: - Public Methods

    /// Update configuration
    func updateConfiguration(_ newConfig: MQTTConfiguration) {
        self.config = newConfig
    }

    /// Publish Home Assistant MQTT Discovery config
    func publishDiscovery() {
        guard mqttService.connectionState.isConnected else {
            Logger.warning("Cannot publish discovery - not connected", log: Logger.homeAssistant)
            return
        }

        let discoveryConfig = HomeAssistantDiscoveryConfig.create(from: config)

        guard let json = discoveryConfig.toJSONString() else {
            Logger.error("Failed to serialize discovery config", log: Logger.homeAssistant)
            return
        }

        Logger.info("Publishing Home Assistant discovery to topic: \(config.discoveryTopic)", log: Logger.homeAssistant)
        Logger.debug("Discovery config JSON: \(json)", log: Logger.homeAssistant)
        print("[HomeAssistant] Publishing discovery to: \(config.discoveryTopic)")
        print("[HomeAssistant] Discovery JSON: \(json)")

        mqttService.publish(
            topic: config.discoveryTopic,
            message: json,
            retain: true,
            qos: .qos1
        )

        isDiscoveryPublished = true
        Logger.info("Discovery published successfully", log: Logger.homeAssistant)
        print("[HomeAssistant] Discovery published successfully")

        // Publish initial state
        publishState()
    }

    /// Remove discovery config (when disabling)
    func removeDiscovery() {
        guard mqttService.connectionState.isConnected else { return }

        Logger.info("Removing Home Assistant discovery config", log: Logger.homeAssistant)

        // Publish empty message to remove discovery
        mqttService.publish(
            topic: config.discoveryTopic,
            message: "",
            retain: true
        )

        isDiscoveryPublished = false
    }

    /// Publish current state to individual topics (for hass-mqtt-mediaplayer)
    func publishState() {
        guard mqttService.connectionState.isConnected else { return }

        let state = mediaRemoteService.currentState
        let volume = volumeService.volume
        let base = config.baseTopic

        // Publish to individual topics
        mqttService.publish(topic: "\(base)/state", message: state.state.rawValue, retain: true)
        mqttService.publish(topic: "\(base)/title", message: state.title ?? "", retain: true)
        mqttService.publish(topic: "\(base)/artist", message: state.artist ?? "", retain: true)
        mqttService.publish(topic: "\(base)/album", message: state.album ?? "", retain: true)
        mqttService.publish(topic: "\(base)/duration", message: "\(Int(state.duration ?? 0))", retain: true)
        mqttService.publish(topic: "\(base)/position", message: "\(Int(state.position ?? 0))", retain: true)
        mqttService.publish(topic: "\(base)/volume", message: String(format: "%.2f", volume), retain: true)
        mqttService.publish(topic: "\(base)/mediatype", message: state.hasTrack ? "music" : "", retain: true)

        // Publish album art if available (base64 encoded)
        if let artworkBase64 = state.artworkBase64 {
            mqttService.publish(topic: "\(base)/albumart", message: artworkBase64, retain: true)
        }

        print("[HomeAssistant] Published state: \(state.state.rawValue), title: \(state.title ?? "nil")")
        Logger.debug("Published state to individual topics", log: Logger.homeAssistant)

        lastPublishedState = Date()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Handle incoming MQTT messages
        mqttService.onMessage = { [weak self] topic, payload in
            Task { @MainActor [weak self] in
                self?.handleMessage(topic: topic, payload: payload)
            }
        }

        // Handle MQTT connection
        mqttService.onConnect = { [weak self] in
            Task { @MainActor [weak self] in
                self?.publishDiscovery()
            }
        }

        // Watch for media state changes
        mediaRemoteService.$currentState
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleStatePublish()
            }
            .store(in: &cancellables)

        // Watch for volume changes
        volumeService.$volume
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleStatePublish()
            }
            .store(in: &cancellables)

        volumeService.$isMuted
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleStatePublish()
            }
            .store(in: &cancellables)
    }

    private func scheduleStatePublish() {
        statePublishTask?.cancel()
        statePublishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.statePublishDebounce ?? 0.1 * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.publishState()
        }
    }

    private func handleMessage(topic: String, payload: String) {
        Logger.commandReceived(payload)
        print("[HomeAssistant] Received command on \(topic): \(payload)")

        // Handle volume set command (separate topic)
        if topic == config.volumeCommandTopic {
            if let volume = Float(payload) {
                Task {
                    let result = await commandExecutor.execute(command: .volumeSet, value: volume)
                    Logger.commandExecuted("volume_set", success: result.success)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    publishState()
                }
            }
            return
        }

        // Handle playback commands (simple string payloads)
        guard topic == config.commandTopic else { return }

        let command: PlayerCommand?
        switch payload.lowercased() {
        case "play":
            command = .play
        case "pause":
            command = .pause
        case "playpause":
            command = .playPause
        case "next":
            command = .nextTrack
        case "previous":
            command = .previousTrack
        default:
            // Try parsing as JSON for backwards compatibility
            if let (cmd, value) = PlayerCommand.parse(from: payload) {
                Task {
                    let result = await commandExecutor.execute(command: cmd, value: value)
                    Logger.commandExecuted(cmd.rawValue, success: result.success)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    publishState()
                }
            } else {
                Logger.warning("Unknown command: \(payload)", log: Logger.homeAssistant)
            }
            return
        }

        if let command = command {
            Task {
                let result = await commandExecutor.execute(command: command, value: nil)
                Logger.commandExecuted(command.rawValue, success: result.success)
                try? await Task.sleep(nanoseconds: 100_000_000)
                publishState()
            }
        }
    }
}
