import Foundation

/// Player state enum matching Home Assistant media_player states
enum PlayerState: String, Codable, Equatable {
    case playing
    case paused
    case idle
    case off
    case unavailable
}

/// Raw JSON structure from media-control CLI
/// Format: {"type":"data","diff":false,"payload":{...}}
struct MediaControlOutput: Decodable {
    let type: String
    let diff: Bool
    let payload: Payload

    struct Payload: Decodable {
        let bundleIdentifier: String?
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let playing: Bool?
        let artworkData: String?  // Base64 encoded
        let artworkMIMEType: String?
    }
}

/// Media state model for the application
struct MediaState: Equatable {
    // Track info
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    var position: TimeInterval?

    // App info
    var appBundleId: String?
    var appName: String?

    // Artwork
    var artworkBase64: String?
    var artworkMimeType: String?

    // State
    var isPlaying: Bool = false
    var timestamp: Date = Date()

    // MARK: - Computed Properties

    var state: PlayerState {
        if appBundleId == nil && title == nil {
            return .idle
        }
        return isPlaying ? .playing : .paused
    }

    var hasTrack: Bool {
        title != nil || artist != nil
    }

    /// Entity picture as data URL for Home Assistant
    var entityPicture: String? {
        guard let base64 = artworkBase64, let mime = artworkMimeType else {
            return nil
        }
        return "data:\(mime);base64,\(base64)"
    }

    // MARK: - Initialization

    static let idle = MediaState()

    init() {}

    init(from output: MediaControlOutput) {
        let payload = output.payload

        self.title = payload.title
        self.artist = payload.artist
        self.album = payload.album
        self.duration = payload.duration
        self.position = payload.elapsedTime
        self.artworkBase64 = payload.artworkData
        self.artworkMimeType = payload.artworkMIMEType

        self.appBundleId = payload.bundleIdentifier
        self.appName = Self.appNameFromBundleId(payload.bundleIdentifier)

        self.isPlaying = payload.playing ?? false
        self.timestamp = Date()
    }

    // MARK: - Helpers

    private static func appNameFromBundleId(_ bundleId: String?) -> String? {
        guard let bundleId = bundleId else { return nil }

        // Well-known app mappings
        let knownApps: [String: String] = [
            "com.spotify.client": "Spotify",
            "com.apple.Music": "Apple Music",
            "com.apple.podcasts": "Podcasts",
            "com.tidal.desktop": "TIDAL",
            "tv.plex.desktop": "Plex",
            "com.plexamp.Plexamp": "Plexamp",
            "com.google.Chrome": "Chrome",
            "org.mozilla.firefox": "Firefox",
            "com.apple.Safari": "Safari",
            "com.brave.Browser": "Brave",
            "com.microsoft.edgemac": "Edge",
            "com.apple.TV": "Apple TV",
            "com.netflix.Netflix": "Netflix",
            "tv.twitch.android": "Twitch",
            "com.amazon.aiv.AIVApp": "Prime Video"
        ]

        if let name = knownApps[bundleId] {
            return name
        }

        // Extract app name from bundle ID (last component, capitalized)
        let components = bundleId.split(separator: ".")
        if let last = components.last {
            return String(last).capitalized
        }

        return nil
    }
}

// MARK: - Home Assistant JSON Output
extension MediaState {
    /// Convert to Home Assistant state JSON
    func toHomeAssistantJSON(volumeLevel: Float, isMuted: Bool) -> [String: Any] {
        var json: [String: Any] = [
            "state": state.rawValue,
            "volume_level": volumeLevel,
            "is_volume_muted": isMuted
        ]

        if let title = title {
            json["media_title"] = title
        }

        if let artist = artist {
            json["media_artist"] = artist
        }

        if let album = album {
            json["media_album_name"] = album
        }

        if let appName = appName {
            json["app_name"] = appName
        }

        if let duration = duration {
            json["media_duration"] = Int(duration)
        }

        if let position = position {
            json["media_position"] = Int(position)
            json["media_position_updated_at"] = ISO8601DateFormatter().string(from: timestamp)
        }

        if let entityPicture = entityPicture {
            json["entity_picture"] = entityPicture
        }

        json["media_content_type"] = hasTrack ? "music" : nil

        return json
    }

    /// Convert to JSON string
    func toJSONString(volumeLevel: Float, isMuted: Bool) -> String? {
        let json = toHomeAssistantJSON(volumeLevel: volumeLevel, isMuted: isMuted)
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
