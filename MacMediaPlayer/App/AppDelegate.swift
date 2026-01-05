import AppKit
import SwiftUI
import Combine

/// Main application delegate handling service lifecycle and menu bar
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Services

    private var mediaRemoteService: MediaRemoteService!
    private var volumeService: VolumeService!
    private var mqttService: MQTTService!
    private var homeAssistantService: HomeAssistantService!
    private var commandExecutor: CommandExecutor!

    // MARK: - UI

    private var statusBarMenuManager: StatusBarMenuManager!
    private var preferencesWindow: NSWindow?

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private var config: MQTTConfiguration = .load()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app to accessory mode (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Initialize services
        initializeServices()

        // Setup UI
        setupStatusBar()

        // Check for media-control binary
        if !mediaRemoteService.isAvailable {
            showMediaControlMissingAlert()
        }

        // Start services
        startServices()

        // Auto-connect if configured
        if config.isValid {
            connectMQTT()
        }

        Logger.info("MacMediaPlayer started", log: Logger.app)
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("MacMediaPlayer shutting down", log: Logger.app)

        // Publish offline status before shutting down
        if mqttService.connectionState.isConnected {
            mqttService.publish(
                topic: config.availabilityTopic,
                message: "offline",
                retain: true
            )
        }

        stopServices()
    }

    // MARK: - Service Initialization

    private func initializeServices() {
        // Create services
        mediaRemoteService = MediaRemoteService()
        volumeService = VolumeService()
        mqttService = MQTTService()
        commandExecutor = CommandExecutor(volumeService: volumeService)

        homeAssistantService = HomeAssistantService(
            mqttService: mqttService,
            mediaRemoteService: mediaRemoteService,
            volumeService: volumeService,
            commandExecutor: commandExecutor,
            config: config
        )

        // Setup state observation for menu updates
        setupStateObservation()
    }

    private func setupStateObservation() {
        // Observe all relevant state changes to update menu
        Publishers.CombineLatest4(
            mediaRemoteService.$currentState,
            mqttService.$connectionState,
            volumeService.$volume,
            volumeService.$isMuted
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] mediaState, connectionState, volume, isMuted in
            self?.updateStatusBarMenu(
                mediaState: mediaState,
                connectionState: connectionState,
                volume: volume,
                isMuted: isMuted
            )
        }
        .store(in: &cancellables)
    }

    private func startServices() {
        // Start media remote streaming
        mediaRemoteService.start()

        // Start volume polling
        volumeService.startPolling()
    }

    private func stopServices() {
        mediaRemoteService.stop()
        volumeService.stopPolling()
        mqttService.disconnect()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusBarMenuManager = StatusBarMenuManager(appDelegate: self)

        // Initial update
        updateStatusBarMenu(
            mediaState: mediaRemoteService.currentState,
            connectionState: mqttService.connectionState,
            volume: volumeService.volume,
            isMuted: volumeService.isMuted
        )
    }

    private func updateStatusBarMenu(
        mediaState: MediaState,
        connectionState: MQTTConnectionState,
        volume: Float,
        isMuted: Bool
    ) {
        let content = StatusBarMenuContent(
            mediaState: mediaState,
            connectionState: connectionState,
            volume: volume,
            isMuted: isMuted,
            onConnect: { [weak self] in self?.connectMQTT() },
            onDisconnect: { [weak self] in self?.disconnectMQTT() },
            onOpenPreferences: { [weak self] in self?.openPreferences() },
            onQuit: { [weak self] in self?.quit() }
        )

        statusBarMenuManager.update(with: content)
    }

    // MARK: - MQTT Connection

    private func connectMQTT() {
        config = .load()

        guard config.isValid else {
            Logger.warning("Cannot connect - invalid configuration", log: Logger.mqtt)
            openPreferences()
            return
        }

        homeAssistantService.updateConfiguration(config)
        mqttService.connect(config: config)
    }

    private func disconnectMQTT() {
        mqttService.disconnect()
    }

    // MARK: - Preferences

    func openPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesWindow()
            let hostingController = NSHostingController(rootView: preferencesView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "\(Constants.appName) Preferences"
            window.styleMask = [.titled, .closable]
            window.center()

            // Handle window close
            window.isReleasedWhenClosed = false

            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Alerts

    private func showMediaControlMissingAlert() {
        let alert = NSAlert()
        alert.messageText = "media-control Not Found"
        alert.informativeText = """
        MacMediaPlayer requires media-control to read Now Playing information.

        Install it via Homebrew:
        \(Constants.MediaControl.brewTapCommand)
        \(Constants.MediaControl.brewInstallCommand)

        The app will continue running but Now Playing data won't be available until media-control is installed.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Homebrew Instructions")
        alert.addButton(withTitle: "Continue Anyway")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/ungive/mediaremote-adapter#installation") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - App Control

    private func quit() {
        NSApp.terminate(nil)
    }
}
