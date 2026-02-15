import SwiftUI

struct TerminalSessionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager

    @State private var commandInput = ""
    @State private var suggestions: [String] = []
    @State private var commandHistory: [String] = []
    @State private var showKeyboardBar = true
    @State private var modifierState: Set<KeyModifier> = []
    @FocusState private var isInputFocused: Bool

    private let quickMacros = ["ls -la", "git status", "tmux ls", "clear", "pwd"]

    private var panes: [PaneState] {
        manager.getPanes(for: host.id)
    }

    private var activePane: PaneState? {
        panes.first { $0.isActive } ?? panes.first
    }

    private var accent: Color {
        host.colorScheme.liquidAccent
    }

    var body: some View {
        VStack(spacing: 8) {
            if let pane = activePane {
                terminalContainerView(pane: pane)
            } else {
                loadingView
            }

            macroToolbar

            if !suggestions.isEmpty {
                autocompleteToolbar
            }

            if !commandHistory.isEmpty && commandInput.isEmpty {
                historyToolbar
            }

            if showKeyboardBar {
                customKeyboardBar
            }

            commandInputView
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: suggestions)
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: showKeyboardBar)
        .onChange(of: commandInput) { _, newValue in
            updateSuggestions(for: newValue)
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func terminalContainerView(pane: PaneState) -> some View {
        NeoGlassCard(accent: accent, cornerRadius: 22, padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    NeoRoboGlyph(symbol: host.colorScheme.glyphSymbol, accent: accent, size: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(host.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundColor(NeoLiquidPalette.textPrimary)
                        Text(pane.workingDirectory)
                            .font(.caption2.monospaced())
                            .foregroundColor(NeoLiquidPalette.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !pane.title.isEmpty {
                        NeoTagPill(text: pane.title, icon: "rectangle.3.group", accent: accent.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                TerminalView(
                    paneId: pane.id,
                    colorScheme: host.colorScheme,
                    renderer: pane.renderer
                )
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(Color.black.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(10)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var loadingView: some View {
        NeoGlassCard(accent: accent, cornerRadius: 22, padding: 20) {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(accent)
                    .scaleEffect(1.15)
                Text("Initializing terminal consciousness...")
                    .font(.footnote)
                    .foregroundColor(NeoLiquidPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
        .padding(.horizontal, 12)
    }

    private var macroToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickMacros, id: \.self) { macro in
                    Button {
                        runMacro(macro)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconFor(macro))
                                .font(.caption2)
                            Text(macro)
                                .font(.caption.monospaced())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(NeoLiquidButtonStyle(tint: accent, prominent: false))
                    .frame(minWidth: 96)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var autocompleteToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        commandInput = suggestion
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconFor(suggestion))
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption.monospaced())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(NeoLiquidButtonStyle(tint: accent, prominent: false))
                }

                Button {
                    if let first = suggestions.first {
                        commandInput = first
                        sendCommand()
                    }
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                }
                .buttonStyle(NeoLiquidButtonStyle(tint: accent))
            }
            .padding(.horizontal, 12)
        }
    }

    private var historyToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commandHistory, id: \.self) { previous in
                    Button {
                        commandInput = previous
                    } label: {
                        Label(previous, systemImage: "clock.arrow.circlepath")
                            .font(.caption.monospaced())
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(NeoLiquidButtonStyle(tint: NeoLiquidPalette.auraRose, prominent: false))
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var customKeyboardBar: some View {
        HStack(spacing: 6) {
            keyButton("Esc", action: sendEscape)
            keyButton("Tab", action: sendTab)

            modifierButton("Ctrl", modifier: .control)
            modifierButton("Alt", modifier: .alt)

            Spacer(minLength: 8)

            keyButton("←") { sendArrowKey(.left) }
            keyButton("↑") { sendArrowKey(.up) }
            keyButton("↓") { sendArrowKey(.down) }
            keyButton("→") { sendArrowKey(.right) }
        }
        .padding(.horizontal, 12)
    }

    private func keyButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 34, minHeight: 30)
        }
        .buttonStyle(NeoLiquidButtonStyle(tint: accent, prominent: false))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func modifierButton(_ label: String, modifier: KeyModifier) -> some View {
        Button {
            if modifierState.contains(modifier) {
                modifierState.remove(modifier)
            } else {
                modifierState.insert(modifier)
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(minWidth: 42, minHeight: 30)
        }
        .buttonStyle(
            NeoLiquidButtonStyle(
                tint: modifierState.contains(modifier) ? NeoLiquidPalette.auraMint : accent,
                prominent: modifierState.contains(modifier)
            )
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var commandInputView: some View {
        NeoGlassCard(accent: accent, cornerRadius: 18, padding: 12) {
            HStack(spacing: 10) {
                TextField("Command...", text: $commandInput)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .onSubmit(sendCommand)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .foregroundColor(NeoLiquidPalette.textPrimary)

                Button {
                    toggleKeyboardBar()
                } label: {
                    Image(systemName: showKeyboardBar ? "keyboard.chevron.compact.down" : "keyboard.chevron.compact.up")
                        .font(.callout)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                }

                Button {
                    sendCommand()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(commandInput.isEmpty ? NeoLiquidPalette.textMuted : accent)
                }
                .disabled(commandInput.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func sendCommand() {
        guard !commandInput.isEmpty else { return }

        let originalCommand = commandInput
        var commandToSend = originalCommand

        if modifierState.contains(.control) {
            commandToSend = applyControlModifier(commandToSend)
            modifierState.remove(.control)
        }

        rememberCommand(originalCommand)

        Task {
            do {
                try await manager.send(hostId: host.id, command: commandToSend + "\n")
                await MainActor.run {
                    commandInput = ""
                    suggestions = []
                }
            } catch {
                print("Error sending command: \(error)")
            }
        }
    }

    private func runMacro(_ macro: String) {
        commandInput = macro
        sendCommand()
    }

    private func rememberCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        commandHistory.removeAll { $0 == trimmed }
        commandHistory.insert(trimmed, at: 0)

        if commandHistory.count > 8 {
            commandHistory = Array(commandHistory.prefix(8))
        }
    }

    private func sendEscape() {
        Task {
            try? await manager.send(hostId: host.id, command: "\u{1B}")
        }
    }

    private func sendTab() {
        Task {
            try? await manager.send(hostId: host.id, command: "\t")
        }
    }

    private enum ArrowDirection { case up, down, left, right }

    private func sendArrowKey(_ direction: ArrowDirection) {
        let sequence: String
        switch direction {
        case .up: sequence = "\u{1B}[A"
        case .down: sequence = "\u{1B}[B"
        case .right: sequence = "\u{1B}[C"
        case .left: sequence = "\u{1B}[D"
        }

        Task {
            try? await manager.send(hostId: host.id, command: sequence)
        }
    }

    private func applyControlModifier(_ command: String) -> String {
        guard let firstChar = command.first else { return command }

        let lower = firstChar.lowercased()
        guard let firstLower = lower.first,
              let ascii = firstLower.asciiValue,
              firstLower >= "a" && firstLower <= "z" else {
            return command
        }

        let asciiVal = ascii - 96
        let controlChar = Character(UnicodeScalar(asciiVal))
        return String(controlChar) + command.dropFirst()
    }

    private func toggleKeyboardBar() {
        withAnimation {
            showKeyboardBar.toggle()
        }
    }

    private func updateSuggestions(for input: String) {
        guard !input.isEmpty else {
            suggestions = []
            return
        }

        var newSuggestions: [String] = []

        if !input.contains(" ") {
            let commands = [
                "ls", "cd", "pwd", "cat", "grep", "find", "mkdir", "rm", "cp", "mv",
                "git", "vim", "nano", "less", "tail", "head", "echo", "touch",
                "chmod", "chown", "ps", "kill", "top", "htop", "df", "du",
                "ssh", "scp", "rsync", "curl", "wget", "tar", "zip", "unzip",
                "tmux", "docker", "kubectl", "npm", "yarn", "pip", "cargo"
            ]
            newSuggestions = commands.filter { $0.hasPrefix(input.lowercased()) }
        }

        if input.hasPrefix("git ") {
            let gitCommands = [
                "git status", "git add .", "git add", "git commit -m \"",
                "git push", "git pull", "git checkout", "git branch",
                "git merge", "git rebase", "git log", "git diff", "git stash"
            ]
            newSuggestions = gitCommands.filter { $0.hasPrefix(input) }
        }

        if input.hasPrefix("tmux ") {
            let tmuxCommands = [
                "tmux new-session", "tmux new-window", "tmux split-window",
                "tmux attach", "tmux detach", "tmux list-sessions",
                "tmux kill-session", "tmux rename-session"
            ]
            newSuggestions = tmuxCommands.filter { $0.hasPrefix(input) }
        }

        if input.hasPrefix("cd ") {
            newSuggestions = ["cd ~", "cd ..", "cd ../..", "cd -", "cd /"]
                .filter { $0.hasPrefix(input) }
        }

        if input.hasPrefix("docker ") {
            let dockerCommands = [
                "docker ps", "docker images", "docker run", "docker stop",
                "docker exec", "docker logs", "docker build", "docker compose up"
            ]
            newSuggestions = dockerCommands.filter { $0.hasPrefix(input) }
        }

        suggestions = Array(newSuggestions.prefix(5))
    }

    private func iconFor(_ suggestion: String) -> String {
        if suggestion.contains("/") { return "folder" }
        if suggestion.hasPrefix("git ") { return "arrow.triangle.branch" }
        if suggestion.hasPrefix("cd ") { return "arrow.right" }
        if suggestion.hasPrefix("docker") { return "cube" }
        if suggestion.hasPrefix("tmux") { return "rectangle.split.3x3" }
        if suggestion.hasPrefix("pwd") { return "scope" }
        return "terminal"
    }
}

enum KeyModifier {
    case control
    case alt
}

#Preview {
    TerminalSessionView(
        host: RemoteHost(
            displayName: "Test",
            hostname: "192.168.1.1",
            username: "user"
        ),
        manager: ConnectionManager()
    )
}
