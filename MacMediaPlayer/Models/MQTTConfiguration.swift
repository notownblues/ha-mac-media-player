import Foundation
import SwiftUI

/// MQTT connection configuration
struct MQTTConfiguration: Codable, Equatable {
    var host: String = ""
    var port: UInt16 = Constants.MQTTDefaults.port
    var username: String = ""
    var useTLS: Bool = false
    var baseTopic: String = Constants.Topics.baseTopic
    var discoveryPrefix: String = "homeassistant"
    var deviceName: String = ""

    // Password is stored in Keychain, not here
    var password: String {
        get { KeychainHelper.shared.mqttPassword ?? "" }
        set { KeychainHelper.shared.mqttPassword = newValue.isEmpty ? nil : newValue }
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !host.isEmpty && port > 0
    }

    var effectivePort: UInt16 {
        if port == Constants.MQTTDefaults.port && useTLS {
            return Constants.MQTTDefaults.tlsPort
        }
        return port
    }

    var clientId: String {
        let hostname = Host.current().localizedName ?? "Mac"
        let sanitized = hostname.replacingOccurrences(of: " ", with: "_")
        return "MacMediaPlayer_\(sanitized)_\(ProcessInfo.processInfo.processIdentifier)"
    }

    var uniqueId: String {
        let hostname = Host.current().localizedName ?? "mac"
        // Sanitize: lowercase, replace spaces with underscores, remove non-alphanumeric chars
        let sanitized = hostname
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        return "mac_media_player_\(sanitized)"
    }

    var effectiveDeviceName: String {
        if !deviceName.isEmpty {
            return deviceName
        }
        return Host.current().localizedName ?? "Mac Media Player"
    }

    // MARK: - Topic Generation

    var discoveryTopic: String {
        "\(discoveryPrefix)/media_player/\(uniqueId)/config"
    }

    var stateTopic: String {
        "\(baseTopic)/state"
    }

    var commandTopic: String {
        "\(baseTopic)/command"
    }

    var volumeCommandTopic: String {
        "\(baseTopic)/set_volume"
    }

    var availabilityTopic: String {
        "\(baseTopic)/available"
    }
}

// MARK: - UserDefaults Integration
extension MQTTConfiguration {
    /// Load configuration from UserDefaults
    static func load() -> MQTTConfiguration {
        let defaults = UserDefaults.standard
        var config = MQTTConfiguration()

        config.host = defaults.string(forKey: Constants.UserDefaultsKeys.mqttHost) ?? ""
        config.port = UInt16(defaults.integer(forKey: Constants.UserDefaultsKeys.mqttPort))
        if config.port == 0 {
            config.port = Constants.MQTTDefaults.port
        }
        config.username = defaults.string(forKey: Constants.UserDefaultsKeys.mqttUsername) ?? ""
        config.useTLS = defaults.bool(forKey: Constants.UserDefaultsKeys.mqttUseTLS)
        config.baseTopic = defaults.string(forKey: Constants.UserDefaultsKeys.baseTopic) ?? Constants.Topics.baseTopic
        config.discoveryPrefix = defaults.string(forKey: Constants.UserDefaultsKeys.discoveryPrefix) ?? "homeassistant"
        config.deviceName = defaults.string(forKey: Constants.UserDefaultsKeys.deviceName) ?? ""

        return config
    }

    /// Save configuration to UserDefaults
    func save() {
        let defaults = UserDefaults.standard

        defaults.set(host, forKey: Constants.UserDefaultsKeys.mqttHost)
        defaults.set(Int(port), forKey: Constants.UserDefaultsKeys.mqttPort)
        defaults.set(username, forKey: Constants.UserDefaultsKeys.mqttUsername)
        defaults.set(useTLS, forKey: Constants.UserDefaultsKeys.mqttUseTLS)
        defaults.set(baseTopic, forKey: Constants.UserDefaultsKeys.baseTopic)
        defaults.set(discoveryPrefix, forKey: Constants.UserDefaultsKeys.discoveryPrefix)
        defaults.set(deviceName, forKey: Constants.UserDefaultsKeys.deviceName)

        defaults.synchronize()
    }
}
