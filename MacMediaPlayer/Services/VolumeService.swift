import Foundation
import Combine
import ISSoundAdditions

/// Service for controlling and monitoring system volume
@MainActor
final class VolumeService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var volume: Float = 0.0
    @Published private(set) var isMuted: Bool = false
    @Published private(set) var isAvailable: Bool = true

    // MARK: - Private Properties

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = Constants.Volume.pollInterval
    private var lastVolume: Float = -1
    private var lastMuted: Bool?

    // MARK: - Initialization

    init() {
        refreshState()
    }

    // MARK: - Public Methods

    /// Start polling for volume changes
    func startPolling() {
        guard pollTimer == nil else { return }

        Logger.info("Starting volume polling", log: Logger.volume)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshState()
            }
        }

        // Initial state
        refreshState()
    }

    /// Stop polling
    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Refresh current volume state
    func refreshState() {
        do {
            let currentVolume = try Sound.output.readVolume()
            let currentMuted = try Sound.output.readMute()

            // Only publish if changed
            if currentVolume != lastVolume {
                volume = currentVolume
                lastVolume = currentVolume
            }

            if lastMuted != currentMuted {
                isMuted = currentMuted
                lastMuted = currentMuted
                Logger.volumeChanged(volume, muted: isMuted)
            }

            isAvailable = true
        } catch {
            Logger.error("Failed to read volume: \(error)", log: Logger.volume)
            isAvailable = false
        }
    }

    /// Set volume level (0.0 to 1.0)
    func setVolume(_ level: Float) {
        let clampedLevel = max(0.0, min(1.0, level))

        do {
            try Sound.output.setVolume(clampedLevel)
            volume = clampedLevel
            lastVolume = clampedLevel
            Logger.volumeChanged(volume, muted: isMuted)
        } catch {
            Logger.error("Failed to set volume: \(error)", log: Logger.volume)
        }
    }

    /// Increase volume by step
    func increaseVolume() {
        setVolume(volume + Constants.Volume.stepSize)
    }

    /// Decrease volume by step
    func decreaseVolume() {
        setVolume(volume - Constants.Volume.stepSize)
    }

    /// Toggle mute state
    func toggleMute() {
        do {
            let newMuted = !isMuted
            try Sound.output.mute(newMuted)
            isMuted = newMuted
            lastMuted = newMuted
            Logger.volumeChanged(volume, muted: isMuted)
        } catch {
            Logger.error("Failed to toggle mute: \(error)", log: Logger.volume)
        }
    }

    /// Set mute state
    func setMute(_ muted: Bool) {
        do {
            try Sound.output.mute(muted)
            isMuted = muted
            lastMuted = muted
            Logger.volumeChanged(volume, muted: isMuted)
        } catch {
            Logger.error("Failed to set mute: \(error)", log: Logger.volume)
        }
    }
}
