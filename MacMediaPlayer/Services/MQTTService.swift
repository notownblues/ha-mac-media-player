import Foundation
import Combine
import CocoaMQTT

/// MQTT connection states
enum MQTTConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

/// Service for MQTT communication
@MainActor
final class MQTTService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var connectionState: MQTTConnectionState = .disconnected
    @Published private(set) var lastError: Error?

    // MARK: - Callbacks

    var onMessage: ((String, String) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?

    // MARK: - Private Properties

    private var mqtt: CocoaMQTT5?
    private var config: MQTTConfiguration?
    private var reconnectTask: Task<Void, Never>?
    private var retryCount = 0
    private let maxRetries = 10

    // MARK: - Public Methods

    /// Connect to MQTT broker
    func connect(config: MQTTConfiguration) {
        guard config.isValid else {
            connectionState = .error("Invalid configuration")
            return
        }

        self.config = config

        Logger.info("Connecting to MQTT broker at \(config.host):\(config.effectivePort)", log: Logger.mqtt)

        connectionState = .connecting

        // Create MQTT client
        let mqtt = CocoaMQTT5(
            clientID: config.clientId,
            host: config.host,
            port: config.effectivePort
        )

        mqtt.username = config.username.isEmpty ? nil : config.username
        mqtt.password = config.password.isEmpty ? nil : config.password
        mqtt.keepAlive = Constants.MQTTDefaults.keepAlive
        mqtt.enableSSL = config.useTLS
        mqtt.allowUntrustCACertificate = true  // For self-signed certs

        // Set Last Will Testament for availability
        let willMessage = CocoaMQTT5Message(
            topic: config.availabilityTopic,
            string: "offline"
        )
        willMessage.retained = true
        willMessage.qos = .qos1
        mqtt.willMessage = willMessage

        mqtt.delegate = self

        self.mqtt = mqtt

        _ = mqtt.connect()
    }

    /// Disconnect from MQTT broker
    func disconnect() {
        Logger.info("Disconnecting from MQTT broker", log: Logger.mqtt)

        reconnectTask?.cancel()
        reconnectTask = nil
        retryCount = 0

        connectionState = .disconnecting

        // Publish offline before disconnecting
        if let config = config {
            publish(topic: config.availabilityTopic, message: "offline", retain: true)
        }

        mqtt?.disconnect()
        mqtt = nil
        config = nil

        connectionState = .disconnected
    }

    /// Publish a message
    func publish(topic: String, message: String, retain: Bool = false, qos: CocoaMQTTQoS = .qos0) {
        guard connectionState.isConnected else {
            Logger.warning("Cannot publish - not connected", log: Logger.mqtt)
            return
        }

        let properties = MqttPublishProperties()
        let msg = CocoaMQTT5Message(topic: topic, string: message)
        msg.retained = retain
        msg.qos = qos

        mqtt?.publish(msg, properties: properties)
    }

    /// Subscribe to a topic
    func subscribe(topic: String, qos: CocoaMQTTQoS = .qos0) {
        guard connectionState.isConnected else {
            Logger.warning("Cannot subscribe - not connected", log: Logger.mqtt)
            return
        }

        mqtt?.subscribe(topic, qos: qos)
    }

    // MARK: - Private Methods

    private func scheduleReconnect() {
        guard let config = config else { return }
        guard retryCount < maxRetries else {
            Logger.error("Max reconnection attempts reached", log: Logger.mqtt)
            connectionState = .error("Max reconnection attempts reached")
            return
        }

        reconnectTask?.cancel()

        let delay = min(
            Constants.MQTTDefaults.reconnectBaseDelay * pow(2, Double(retryCount)),
            Constants.MQTTDefaults.reconnectMaxDelay
        )

        retryCount += 1

        Logger.info("Scheduling reconnect in \(Int(delay))s (attempt \(retryCount))", log: Logger.mqtt)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.connect(config: config)
            }
        }
    }
}

// MARK: - CocoaMQTT5Delegate
extension MQTTService: CocoaMQTT5Delegate {
    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        Task { @MainActor in
            if ack == .success {
                Logger.mqttConnected(host: config?.host ?? "", port: config?.effectivePort ?? 0)
                print("[MQTT] Connected successfully to \(config?.host ?? ""):\(config?.effectivePort ?? 0)")
                connectionState = .connected
                retryCount = 0

                // Subscribe to command topics
                if let config = config {
                    print("[MQTT] Subscribing to command topic: \(config.commandTopic)")
                    subscribe(topic: config.commandTopic, qos: .qos1)

                    print("[MQTT] Subscribing to volume command topic: \(config.volumeCommandTopic)")
                    subscribe(topic: config.volumeCommandTopic, qos: .qos1)

                    // Publish online status
                    print("[MQTT] Publishing online status to: \(config.availabilityTopic)")
                    publish(topic: config.availabilityTopic, message: "online", retain: true, qos: .qos1)
                }

                print("[MQTT] Calling onConnect callback...")
                onConnect?()
                print("[MQTT] onConnect callback completed")
            } else {
                Logger.error("Connection rejected: \(ack)", log: Logger.mqtt)
                print("[MQTT] Connection rejected: \(ack)")
                connectionState = .error("Connection rejected: \(ack)")
                scheduleReconnect()
            }
        }
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        // Message published successfully
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {
        // Publish acknowledged
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {
        // Publish received (QoS 2)
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        Task { @MainActor in
            let topic = message.topic
            let payload = message.string ?? ""

            Logger.debug("Received message on \(topic): \(payload)", log: Logger.mqtt)

            onMessage?(topic, payload)
        }
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        Task { @MainActor in
            if !failed.isEmpty {
                Logger.warning("Failed to subscribe to: \(failed)", log: Logger.mqtt)
            }
            for topic in success.allKeys {
                Logger.debug("Subscribed to: \(topic)", log: Logger.mqtt)
            }
        }
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {
        Task { @MainActor in
            Logger.debug("Unsubscribed from: \(topics)", log: Logger.mqtt)
        }
    }

    nonisolated func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        // Ping sent
    }

    nonisolated func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        // Pong received
    }

    nonisolated func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: (any Error)?) {
        Task { @MainActor in
            if let error = err {
                Logger.mqttDisconnected(reason: error.localizedDescription)
                lastError = error
                connectionState = .error(error.localizedDescription)
                scheduleReconnect()
            } else {
                Logger.mqttDisconnected()
                connectionState = .disconnected
            }

            onDisconnect?()
        }
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        Task { @MainActor in
            Logger.warning("Disconnect reason: \(reasonCode)", log: Logger.mqtt)
        }
    }

    nonisolated func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        Task { @MainActor in
            Logger.debug("Auth reason: \(reasonCode)", log: Logger.mqtt)
        }
    }
}
