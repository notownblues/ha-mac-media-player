import SwiftUI

/// SwiftUI view for displaying Now Playing information
struct NowPlayingView: View {
    let state: MediaState
    let volume: Float
    let isMuted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: stateIcon)
                    .font(.title2)
                    .foregroundColor(stateColor)

                Text(state.state.rawValue.capitalized)
                    .font(.headline)

                Spacer()

                if let appName = state.appName {
                    Text(appName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            if state.hasTrack {
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    if let title = state.title {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }

                    if let artist = state.artist {
                        Text(artist)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let album = state.album {
                        Text(album)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                // Progress bar
                if let duration = state.duration, let position = state.position, duration > 0 {
                    VStack(spacing: 2) {
                        ProgressView(value: position, total: duration)
                            .progressViewStyle(.linear)

                        HStack {
                            Text(formatTime(position))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Nothing playing")
                    .foregroundColor(.secondary)
                    .italic()
            }

            Divider()

            // Volume
            HStack {
                Image(systemName: volumeIcon)
                    .foregroundColor(isMuted ? .secondary : .primary)

                if isMuted {
                    Text("Muted")
                        .foregroundColor(.secondary)
                } else {
                    ProgressView(value: Double(volume))
                        .progressViewStyle(.linear)

                    Text("\(Int(volume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Helpers

    private var stateIcon: String {
        switch state.state {
        case .playing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .idle: return "stop.circle"
        case .off, .unavailable: return "xmark.circle"
        }
    }

    private var stateColor: Color {
        switch state.state {
        case .playing: return .green
        case .paused: return .yellow
        case .idle: return .secondary
        case .off, .unavailable: return .red
        }
    }

    private var volumeIcon: String {
        if isMuted { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
