# T-Rex - TMUX Terminal Multiplexer for iPhone

A native iOS terminal multiplexer that connects to remote hosts running tmux, giving you full terminal access with an intuitive touch interface.

## Features

- 🖥️ **Multi-host management** - Connect to multiple remote servers
- 🎨 **Color-coded hosts** - Visually distinguish between different machines
- ⚡ **Smart autocomplete** - Fast command suggestions with one-tap accept
- 📱 **Native iOS UI** - Familiar card-based interface matching iOS design patterns
- 🔐 **Secure SSH** - Password-based authentication (key-based coming soon)
- 🎯 **TMUX Control Mode** - Full tmux integration via control mode protocol

## Project Structure

```
TRex/
├── Package.swift                          # Swift package manifest
├── Sources/TRex/
│   ├── Core/                             # Core functionality
│   │   ├── TmuxControlMode.swift         # Tmux control mode parser
│   │   ├── SSHConnection.swift           # SSH connection handler
│   │   ├── TerminalRenderer.swift        # ANSI escape sequence renderer
│   │   └── ConnectionManager.swift       # Manages all host connections
│   ├── Models/                           # Data models
│   │   └── RemoteHost.swift              # Host configuration & color schemes
│   └── UI/                               # User interface
│       ├── SessionListView.swift         # Main host list screen
│       ├── SessionConnectionView.swift   # Connection setup flow
│       ├── AddHostSheet.swift            # Add new host sheet
│       ├── TerminalSessionView.swift     # Active terminal session
│       └── TerminalView+iOS.swift        # Terminal rendering view
└── Tests/TRexTests/                      # Unit tests
```

## How It Works

1. **SSH Connection** - Connects to remote host via SSH
2. **TMUX Control Mode** - Starts tmux with `-CC` flag for machine-readable output
3. **Message Parsing** - Parses tmux control messages (%output, %layout-change, etc.)
4. **Terminal Rendering** - Renders ANSI escape sequences with full color support
5. **Multi-session** - Each host can have multiple tmux windows/panes

## Setup Requirements

### On Your Remote Host (macOS/Linux)

```bash
# Install tmux if not already installed
# macOS:
brew install tmux

# Ubuntu/Debian:
sudo apt install tmux

# Ensure SSH is enabled
# macOS: System Preferences > Sharing > Remote Login
# Linux: sudo systemctl enable ssh
```

### In Your iOS Project

1. Add this package to your Xcode project
2. Import `TRex` in your app
3. Present `SessionListView` as your main view

```swift
import SwiftUI
import TRex

@main
struct TRexApp: App {
    var body: some Scene {
        WindowGroup {
            SessionListView()
        }
    }
}
```

## Usage

### Adding a Host

1. Tap the **+** button
2. Enter display name (e.g., "MacBook Pro")
3. Enter hostname (IP address or domain)
4. Enter SSH username
5. Choose a color theme
6. Tap **Add**

### Connecting

1. Tap a host from the list
2. Enter your SSH password
3. Tap **Connect**
4. Terminal session starts automatically

### Using the Terminal

- **Type commands** using the on-screen keyboard
- **Autocomplete** suggestions appear above keyboard
- **Tap a suggestion** to fill it in
- **Tap the arrow button** to accept first suggestion and submit
- **Pull down** to disconnect

## Smart Autocomplete

The autocomplete engine suggests:
- Common commands (ls, cd, git, vim, etc.)
- Git subcommands (status, commit, push, etc.)
- Directory navigation shortcuts
- Command history (coming soon)
- Path completion (coming soon)

## Color Schemes

Each host can be assigned a color for easy identification:
- **Ocean** (Blue) - Perfect for your main laptop
- **Forest** (Green) - Great for production servers
- **Sunset** (Orange) - Dev/staging environments
- **Midnight** (Purple) - Database servers
- **Ruby** (Red) - Critical infrastructure
- **Emerald** (Teal) - Personal projects

## Architecture Decisions

### Why TMUX Control Mode?

- **Reliable parsing** - Machine-readable output vs. screen scraping
- **Session persistence** - Sessions survive disconnects
- **Window/pane support** - Native tmux multiplexing
- **Mature protocol** - Well-documented and stable

### Why Actor-Based Concurrency?

- **Thread safety** - No race conditions on connection state
- **Modern Swift** - Uses Swift's native concurrency model
- **Clean separation** - Each connection is an isolated actor

### Why SwiftSSH?

- **Pure Swift** - No C dependencies
- **Modern API** - Async/await support
- **Active development** - Well-maintained

Note: You may need to swap for NMSSH if SwiftSSH has issues. Both are specified in Package.swift.

## Roadmap

- [ ] SSH key-based authentication
- [ ] Split pane support (horizontal/vertical)
- [ ] Multiple windows per session
- [ ] Command history with fuzzy search
- [ ] Path autocompletion from remote filesystem
- [ ] Session state restoration
- [ ] Custom keyboard shortcuts
- [ ] macOS companion app
- [ ] Snippet library for common commands
- [ ] Scripting/automation support

## Known Limitations

- **No local shell** - This is remote-only (by design)
- **No copy/paste** - Coming soon
- **Single pane** - Multi-pane layout in progress
- **Password-only auth** - SSH keys coming soon

## Development

### Building

```bash
swift build
swift test
```

### Building a Standalone macOS App Bundle

Build a proper `.app` bundle (instead of running the executable via Terminal):

```bash
./scripts/build-macos-app.sh
open dist/iTMUX.app
```

This launch path allows the GUI app to become the active first responder and receive keyboard input directly.

### Testing with a Remote Host

```bash
# On your Mac, start an SSH server
sudo systemsetup -setremotelogin on

# Get your IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Connect from the iOS app using:
# - Hostname: [your IP]
# - Username: [your Mac username]
# - Password: [your Mac password]
```

## License

MIT License - See LICENSE file for details

## Credits

Built with:
- [SwiftSSH](https://github.com/Frugghi/SwiftSSH) - SSH client library
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer

Inspired by:
- Blink Shell
- Prompt
- Terminus
