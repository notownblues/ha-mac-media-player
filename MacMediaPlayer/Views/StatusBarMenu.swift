import SwiftUI
import AppKit

/// Status bar menu content
struct StatusBarMenuContent {
    let mediaState: MediaState
    let connectionState: MQTTConnectionState
    let volume: Float
    let isMuted: Bool

    var onConnect: () -> Void
    var onDisconnect: () -> Void
    var onOpenPreferences: () -> Void
    var onQuit: () -> Void
}

/// Creates and manages the status bar menu
final class StatusBarMenuManager {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private var content: StatusBarMenuContent?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupStatusItem()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note.house", accessibilityDescription: "MacMediaPlayer")
            button.image?.isTemplate = true
        }

        menu = NSMenu()
        statusItem?.menu = menu
    }

    // MARK: - Update

    func update(with content: StatusBarMenuContent) {
        self.content = content
        rebuildMenu()
        updateIcon()
    }

    private func updateIcon() {
        guard let content = content else { return }

        let imageName: String
        let color: NSColor?

        switch content.connectionState {
        case .connected:
            imageName = content.mediaState.isPlaying ? "play.circle.fill" : "music.note.house.fill"
            color = .systemGreen
        case .connecting:
            imageName = "music.note.house"
            color = .systemYellow
        case .error:
            imageName = "exclamationmark.triangle.fill"
            color = .systemRed
        default:
            imageName = "music.note.house"
            color = nil
        }

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            var image = NSImage(systemSymbolName: imageName, accessibilityDescription: "MacMediaPlayer")
            image = image?.withSymbolConfiguration(config)
            image?.isTemplate = color == nil

            button.image = image
            button.contentTintColor = color
        }
    }

    private func rebuildMenu() {
        guard let menu = menu, let content = content else { return }

        menu.removeAllItems()

        // Now Playing section
        addNowPlayingSection(to: menu, state: content.mediaState)

        menu.addItem(.separator())

        // Connection status
        addConnectionSection(to: menu, state: content.connectionState)

        menu.addItem(.separator())

        // Volume section
        addVolumeSection(to: menu, volume: content.volume, muted: content.isMuted)

        menu.addItem(.separator())

        // Actions
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit \(Constants.appName)", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Menu Sections

    private func addNowPlayingSection(to menu: NSMenu, state: MediaState) {
        let headerItem = NSMenuItem(title: "Now Playing", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        if state.hasTrack {
            if let title = state.title {
                let titleItem = NSMenuItem(title: "  \(title)", action: nil, keyEquivalent: "")
                titleItem.isEnabled = false
                menu.addItem(titleItem)
            }

            if let artist = state.artist {
                let artistItem = NSMenuItem(title: "  \(artist)", action: nil, keyEquivalent: "")
                artistItem.isEnabled = false
                artistItem.attributedTitle = NSAttributedString(
                    string: "  \(artist)",
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                )
                menu.addItem(artistItem)
            }

            if let appName = state.appName {
                let appItem = NSMenuItem(title: "  via \(appName)", action: nil, keyEquivalent: "")
                appItem.isEnabled = false
                appItem.attributedTitle = NSAttributedString(
                    string: "  via \(appName)",
                    attributes: [
                        .foregroundColor: NSColor.tertiaryLabelColor,
                        .font: NSFont.systemFont(ofSize: 11)
                    ]
                )
                menu.addItem(appItem)
            }
        } else {
            let nothingItem = NSMenuItem(title: "  Nothing playing", action: nil, keyEquivalent: "")
            nothingItem.isEnabled = false
            nothingItem.attributedTitle = NSAttributedString(
                string: "  Nothing playing",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(nothingItem)
        }

        // State indicator
        let stateIcon: String
        switch state.state {
        case .playing: stateIcon = "▶"
        case .paused: stateIcon = "⏸"
        case .idle: stateIcon = "⏹"
        default: stateIcon = "○"
        }

        let stateItem = NSMenuItem(title: "  \(stateIcon) \(state.state.rawValue.capitalized)", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
    }

    private func addConnectionSection(to menu: NSMenu, state: MQTTConnectionState) {
        let statusIcon: String
        switch state {
        case .connected: statusIcon = "🟢"
        case .connecting: statusIcon = "🟡"
        case .error: statusIcon = "🔴"
        default: statusIcon = "⚪"
        }

        let statusItem = NSMenuItem(title: "\(statusIcon) MQTT: \(state.description)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if state.isConnected {
            let disconnectItem = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "")
            disconnectItem.target = self
            menu.addItem(disconnectItem)
        } else if case .error = state {
            let reconnectItem = NSMenuItem(title: "Reconnect", action: #selector(connect), keyEquivalent: "")
            reconnectItem.target = self
            menu.addItem(reconnectItem)
        } else if case .disconnected = state {
            let connectItem = NSMenuItem(title: "Connect", action: #selector(connect), keyEquivalent: "")
            connectItem.target = self
            menu.addItem(connectItem)
        }
    }

    private func addVolumeSection(to menu: NSMenu, volume: Float, muted: Bool) {
        let volumePercent = Int(volume * 100)
        let volumeIcon = muted ? "🔇" : (volumePercent > 50 ? "🔊" : "🔉")
        let volumeText = muted ? "Muted" : "\(volumePercent)%"

        let volumeItem = NSMenuItem(title: "\(volumeIcon) Volume: \(volumeText)", action: nil, keyEquivalent: "")
        volumeItem.isEnabled = false
        menu.addItem(volumeItem)
    }

    // MARK: - Actions

    @objc private func connect() {
        content?.onConnect()
    }

    @objc private func disconnect() {
        content?.onDisconnect()
    }

    @objc private func openPreferences() {
        content?.onOpenPreferences()
    }

    @objc private func quit() {
        content?.onQuit()
    }
}
