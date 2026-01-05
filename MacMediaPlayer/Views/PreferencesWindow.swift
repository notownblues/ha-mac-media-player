import SwiftUI

/// Preferences window for MQTT configuration
struct PreferencesWindow: View {
    @AppStorage(Constants.UserDefaultsKeys.mqttHost) private var host = ""
    @AppStorage(Constants.UserDefaultsKeys.mqttPort) private var port = Int(Constants.MQTTDefaults.port)
    @AppStorage(Constants.UserDefaultsKeys.mqttUsername) private var username = ""
    @AppStorage(Constants.UserDefaultsKeys.mqttUseTLS) private var useTLS = false
    @AppStorage(Constants.UserDefaultsKeys.baseTopic) private var baseTopic = Constants.Topics.baseTopic
    @AppStorage(Constants.UserDefaultsKeys.discoveryPrefix) private var discoveryPrefix = "homeassistant"
    @AppStorage(Constants.UserDefaultsKeys.deviceName) private var deviceName = ""
    @AppStorage(Constants.UserDefaultsKeys.startAtLogin) private var startAtLogin = false

    @State private var password = ""
    @State private var showingPassword = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            connectionTab
                .tabItem {
                    Label("Connection", systemImage: "network")
                }
                .tag(0)

            topicsTab
                .tabItem {
                    Label("Topics", systemImage: "arrow.left.arrow.right")
                }
                .tag(1)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .padding()
        .frame(width: 450, height: 350)
        .onAppear {
            password = KeychainHelper.shared.mqttPassword ?? ""
        }
    }

    // MARK: - Connection Tab

    private var connectionTab: some View {
        Form {
            Section {
                TextField("Broker Host", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .help("MQTT broker hostname or IP address")

                HStack {
                    TextField("Port", value: $port, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Toggle("Use TLS", isOn: $useTLS)
                }
            } header: {
                Text("MQTT Broker")
            }

            Section {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)

                HStack {
                    if showingPassword {
                        TextField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showingPassword.toggle() }) {
                        Image(systemName: showingPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
                .onChange(of: password) { newValue in
                    KeychainHelper.shared.mqttPassword = newValue.isEmpty ? nil : newValue
                }
            } header: {
                Text("Authentication")
            }

            Section {
                TextField("Device Name", text: $deviceName)
                    .textFieldStyle(.roundedBorder)
                    .help("Name shown in Home Assistant (defaults to computer name)")

                Toggle("Start at Login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Topics Tab

    private var topicsTab: some View {
        Form {
            Section {
                TextField("Base Topic", text: $baseTopic)
                    .textFieldStyle(.roundedBorder)
                    .help("Base topic for state and commands")

                TextField("Discovery Prefix", text: $discoveryPrefix)
                    .textFieldStyle(.roundedBorder)
                    .help("Home Assistant MQTT discovery prefix")
            } header: {
                Text("MQTT Topics")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    topicRow("Discovery:", "\(discoveryPrefix)/media_player/mac_media_player_*/config")
                    topicRow("State:", "\(baseTopic)/state")
                    topicRow("Commands:", "\(baseTopic)/set")
                    topicRow("Availability:", "\(baseTopic)/availability")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            } header: {
                Text("Effective Topics")
            }
        }
        .formStyle(.grouped)
    }

    private func topicRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text(Constants.appName)
                .font(.title)

            Text("Version \(Constants.appVersion)")
                .foregroundColor(.secondary)

            Divider()

            Text("Exposes your Mac as a media_player entity in Home Assistant via MQTT.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/notownblues/ha-mac-media-player")!)
                Text("•")
                Link("Report Issue", destination: URL(string: "https://github.com/notownblues/ha-mac-media-player/issues")!)
            }
            .font(.caption)
        }
        .padding()
    }

    // MARK: - Helpers

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Launch at login implementation would use SMAppService on macOS 13+
        // or LSSharedFileList on older versions
        Logger.info("Launch at login: \(enabled)", log: Logger.app)
    }
}
