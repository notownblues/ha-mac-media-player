# MacMediaPlayer

<p align="center">
  <img src="mmp-icon.png" alt="MacMediaPlayer Icon" width="128" height="128">
</p>

<p align="center">
  <strong>A lightweight macOS menu bar app that exposes your Mac as a <code>media_player</code> entity in Home Assistant via MQTT.</strong>
</p>

<p align="center">
  <img src="mac_media_player-app-preview.png" alt="MacMediaPlayer App Preview" width="600">
</p>

## Features

- **Real-time Now Playing info** - Track title, artist, album, and app name
- **Volume control** - Set volume, mute/unmute from Home Assistant
- **Playback control** - Play, pause, next, previous track
- **MQTT Discovery** - Automatically appears in Home Assistant
- **Lightweight** - Runs in menu bar, no dock icon
- **macOS 15.4+ compatible** - Uses mediaremote-adapter for Now Playing access

<p align="center">
  <img src="mac_media_player-preview.png" alt="Home Assistant Media Player Preview" width="400">
</p>

## Use Cases

### Voice Assistant Audio Ducking

Expose your Mac Mini (or any Mac) as a media player entity in Home Assistant so that **Voice Preview Edition** or any Assist satellite can automatically duck (lower) the Mac's audio when listening for voice commands.

Use the [HA Voice room MP volume](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fluka6000%2Fhass-workshop%2Fblob%2Fmain%2Fblueprints%2FHA_Voice_room_MP_volume.yaml) blueprint to:

- Automatically lower Mac volume when your voice assistant starts listening
- Restore volume when the assistant finishes
- Configure the ducking factor (how much to reduce volume)
- Works with any Assist satellite in the same room

This is useful for setups where your Mac Mini serves as a media center and you want voice commands to be clearly heard without manually pausing or lowering audio.

### Other Automations

```yaml
automation:
  - alias: "Pause Mac when leaving home"
    trigger:
      - platform: zone
        entity_id: person.me
        zone: zone.home
        event: leave
    action:
      - service: media_player.media_pause
        target:
          entity_id: media_player.mac_media_player_macbook
```

## Requirements

- macOS 13.0 or later
- [media-control](https://github.com/ungive/mediaremote-adapter) CLI tool
- MQTT broker (e.g., Mosquitto, Home Assistant MQTT add-on)
- Home Assistant with MQTT integration

## Installation

### Homebrew (Recommended)

```bash
# Add the tap
brew tap notownblues/ha-mac-media-player

# Install the app
brew install macmediaplayer

# Link to Applications (optional)
ln -sf $(brew --prefix)/opt/macmediaplayer/MacMediaPlayer.app /Applications/
```

### Install Dependencies

```bash
# Required for Now Playing functionality
brew tap ungive/media-control
brew install media-control
```

### Quick Install (From Source)

```bash
# Clone the repository
git clone https://github.com/notownblues/ha-mac-media-player.git
cd ha-mac-media-player

# Run the installer
./scripts/install.sh
```

The installer will:
- Check for dependencies
- Build the app with the proper icon
- Install to /Applications
- Optionally launch the app

### Manual Install with Make

```bash
# Clone and build
git clone https://github.com/notownblues/ha-mac-media-player.git
cd ha-mac-media-player

# Build the .app bundle
make bundle

# Install to /Applications
make install

# Or just run without installing
make run
```

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make build` | Build the Swift executable |
| `make bundle` | Create the .app bundle with icon |
| `make install` | Install to /Applications |
| `make uninstall` | Remove from /Applications |
| `make run` | Build and launch |
| `make clean` | Clean build artifacts |

### Open in Xcode

```bash
open Package.swift
```

Then build and run (Cmd+R).

## Configuration

1. Click the menu bar icon
2. Select "Preferences..."
3. Enter your MQTT broker details:
   - **Host**: Your MQTT broker address (e.g., `homeassistant.local`)
   - **Port**: MQTT port (default: 1883, TLS: 8883)
   - **Username/Password**: If authentication is required
4. Click Connect

The app will automatically publish a discovery config to Home Assistant.

## Home Assistant Integration

Once connected, a new `media_player` entity will appear in Home Assistant:

```yaml
media_player.mac_media_player_<hostname>
```

### Supported Features

| Feature | Description |
|---------|-------------|
| `state` | playing, paused, idle |
| `volume_level` | 0.0 - 1.0 |
| `is_volume_muted` | true/false |
| `media_title` | Current track title |
| `media_artist` | Artist name |
| `media_album_name` | Album name |
| `app_name` | Source app (Spotify, Apple Music, etc.) |
| `media_duration` | Track duration in seconds |
| `media_position` | Current position in seconds |

### Supported Commands

| Command | Action |
|---------|--------|
| `media_play` | Start playback |
| `media_pause` | Pause playback |
| `media_play_pause` | Toggle play/pause |
| `media_next_track` | Next track |
| `media_previous_track` | Previous track |
| `volume_set` | Set volume (0.0-1.0) |
| `volume_up` | Increase volume by 5% |
| `volume_down` | Decrease volume by 5% |
| `volume_mute` | Toggle mute |

### Example Lovelace Card

```yaml
type: media-control
entity: media_player.mac_media_player_macbook
```

## MQTT Topics

| Topic | Purpose |
|-------|---------|
| `homeassistant/media_player/<id>/config` | Discovery config (retained) |
| `mac_media_player/state` | Current state JSON (retained) |
| `mac_media_player/availability` | online/offline (retained) |
| `mac_media_player/set` | Commands (subscribe) |

## Troubleshooting

### "media-control not found"

Install the media-control CLI:

```bash
brew tap ungive/media-control
brew install media-control
```

### Not connecting to MQTT broker

1. Verify broker address and port
2. Check if authentication is required
3. Ensure firewall allows connection
4. Try enabling TLS if broker requires it

### Entity not appearing in Home Assistant

1. Ensure MQTT integration is configured in HA
2. Check MQTT discovery is enabled (default prefix: `homeassistant`)
3. Verify broker connection in app menu bar

### Now Playing not updating

1. Ensure media-control is installed and working: `media-control stream`
2. Some apps may not publish Now Playing info
3. Check Console.app for errors from MacMediaPlayer

## Building from Source

### Requirements

- Xcode 15.0+
- Swift 5.9+

### Dependencies (via Swift Package Manager)

- [CocoaMQTT](https://github.com/emqx/CocoaMQTT) - MQTT 5.0 client
- [ISSoundAdditions](https://github.com/InerziaSoft/ISSoundAdditions) - Volume control

### Build

```bash
swift build -c release
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file.

## Acknowledgments

- [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) - For the macOS 15.4+ Now Playing workaround
- [CocoaMQTT](https://github.com/emqx/CocoaMQTT) - Swift MQTT client
- [ISSoundAdditions](https://github.com/InerziaSoft/ISSoundAdditions) - macOS volume control
- [HA Voice room MP volume blueprint](https://github.com/luka6000/hass-workshop) - Audio ducking automation
