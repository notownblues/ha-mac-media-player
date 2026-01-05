import Foundation

enum Constants {
    // MARK: - App Info
    static let appName = "MacMediaPlayer"
    static let appVersion = "1.0.0"
    static let bundleIdentifier = "com.macmediaplayer.app"

    // MARK: - MQTT Topics
    enum Topics {
        static let discoveryPrefix = "homeassistant"
        static let baseTopic = "mac_media_player"

        static var discoveryConfig: String {
            "\(discoveryPrefix)/media_player/\(baseTopic)/config"
        }

        static var state: String {
            "\(baseTopic)/state"
        }

        static var availability: String {
            "\(baseTopic)/availability"
        }

        static var command: String {
            "\(baseTopic)/set"
        }
    }

    // MARK: - MQTT Defaults
    enum MQTTDefaults {
        static let port: UInt16 = 1883
        static let tlsPort: UInt16 = 8883
        static let keepAlive: UInt16 = 60
        static let reconnectBaseDelay: TimeInterval = 1.0
        static let reconnectMaxDelay: TimeInterval = 300.0
    }

    // MARK: - Media Control Binary
    enum MediaControl {
        static let binaryPaths = [
            "/opt/homebrew/bin/media-control",  // Apple Silicon
            "/usr/local/bin/media-control"       // Intel
        ]

        static let brewTapCommand = "brew tap ungive/media-control"
        static let brewInstallCommand = "brew install media-control"
    }

    // MARK: - Home Assistant
    enum HomeAssistant {
        // Supported features bitmask
        // PAUSE=1, VOLUME_SET=4, VOLUME_MUTE=8, PREVIOUS_TRACK=16,
        // NEXT_TRACK=32, PLAY=128, STOP=256, VOLUME_STEP=1024
        static let supportedFeatures = 1 | 4 | 8 | 16 | 32 | 128 | 256 | 1024
    }

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let mqttHost = "mqttHost"
        static let mqttPort = "mqttPort"
        static let mqttUsername = "mqttUsername"
        static let mqttUseTLS = "mqttUseTLS"
        static let baseTopic = "baseTopic"
        static let discoveryPrefix = "discoveryPrefix"
        static let startAtLogin = "startAtLogin"
        static let deviceName = "deviceName"
    }

    // MARK: - Keychain
    enum Keychain {
        static let service = "com.macmediaplayer.mqtt"
        static let passwordKey = "mqttPassword"
    }

    // MARK: - Volume
    enum Volume {
        static let stepSize: Float = 0.05  // 5% step
        static let pollInterval: TimeInterval = 0.5  // 500ms
    }
}
