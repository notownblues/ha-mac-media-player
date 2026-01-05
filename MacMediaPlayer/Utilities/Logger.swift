import Foundation
import os.log

/// Unified logging utility using Apple's os.log
enum Logger {
    private static let subsystem = Constants.bundleIdentifier

    static let app = OSLog(subsystem: subsystem, category: "App")
    static let mqtt = OSLog(subsystem: subsystem, category: "MQTT")
    static let media = OSLog(subsystem: subsystem, category: "MediaRemote")
    static let volume = OSLog(subsystem: subsystem, category: "Volume")
    static let homeAssistant = OSLog(subsystem: subsystem, category: "HomeAssistant")

    // MARK: - Logging Methods

    static func debug(_ message: String, log: OSLog = app) {
        os_log(.debug, log: log, "%{public}s", message)
    }

    static func info(_ message: String, log: OSLog = app) {
        os_log(.info, log: log, "%{public}s", message)
    }

    static func warning(_ message: String, log: OSLog = app) {
        os_log(.default, log: log, "WARNING: %{public}s", message)
    }

    static func error(_ message: String, log: OSLog = app) {
        os_log(.error, log: log, "%{public}s", message)
    }

    static func fault(_ message: String, log: OSLog = app) {
        os_log(.fault, log: log, "%{public}s", message)
    }
}

// MARK: - Convenience Extensions
extension Logger {
    static func mqttConnected(host: String, port: UInt16) {
        info("Connected to MQTT broker at \(host):\(port)", log: mqtt)
    }

    static func mqttDisconnected(reason: String? = nil) {
        if let reason = reason {
            warning("Disconnected from MQTT broker: \(reason)", log: mqtt)
        } else {
            info("Disconnected from MQTT broker", log: mqtt)
        }
    }

    static func mqttError(_ error: Error) {
        self.error("MQTT error: \(error.localizedDescription)", log: mqtt)
    }

    static func mediaStateChanged(title: String?, artist: String?, state: String) {
        let trackInfo = [title, artist].compactMap { $0 }.joined(separator: " - ")
        debug("Media state: \(state) - \(trackInfo.isEmpty ? "No track" : trackInfo)", log: media)
    }

    static func volumeChanged(_ level: Float, muted: Bool) {
        debug("Volume: \(Int(level * 100))% (muted: \(muted))", log: volume)
    }

    static func commandReceived(_ command: String) {
        info("Received command: \(command)", log: homeAssistant)
    }

    static func commandExecuted(_ command: String, success: Bool) {
        if success {
            debug("Command executed: \(command)", log: homeAssistant)
        } else {
            warning("Command failed: \(command)", log: homeAssistant)
        }
    }
}
