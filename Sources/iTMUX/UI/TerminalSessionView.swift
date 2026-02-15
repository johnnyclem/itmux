import SwiftUI

struct TerminalSessionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager
    
    @State private var commandInput = ""
    @State private var suggestions: [String] = []
    @State private var showKeyboardBar = true
    @State private var modifierState: Set<KeyModifier> = []
    @FocusState private var isInputFocused: Bool
    
    private var panes: [PaneState] {
        manager.getPanes(for: host.id)
    }
    
    private var activePane: PaneState? {
        panes.first { $0.isActive } ?? panes.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let pane = activePane {
                terminalContainerView(pane: pane)
            } else {
                loadingView
            }
            
            if !suggestions.isEmpty {
                autocompleteToolbar
            }
            
            if showKeyboardBar {
                customKeyboardBar
            }
            
            commandInputView
        }
        .animation(.spring(response: 0.25), value: suggestions)
        .animation(.spring(response: 0.25), value: showKeyboardBar)
        .onChange(of: commandInput) { _, newValue in
            updateSuggestions(for: newValue)
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func terminalContainerView(pane: PaneState) -> some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text(host.displayName)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(pane.workingDirectory)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if !pane.title.isEmpty {
                    Text("•")
                        .foregroundColor(.gray)
                    Text(pane.title)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(host.colorScheme.statusBarColor)
            
            TerminalView(
                paneId: pane.id,
                colorScheme: host.colorScheme,
                renderer: pane.renderer
            )
            .background(Color.black)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(host.colorScheme.borderColor, lineWidth: 2)
        )
        .padding(12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.2)
            
            Text("Initializing terminal...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
                
                Button {
                    if let first = suggestions.first {
                        commandInput = first
                        sendCommand()
                    }
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.cyan)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }
    
    private var customKeyboardBar: some View {
        HStack(spacing: 4) {
            keyButton("Esc", action: sendEscape)
            keyButton("Tab", action: sendTab)
            
            Spacer()
            
            modifierButton("Ctrl", modifier: .control)
            modifierButton("Alt", modifier: .alt)
            
            Spacer()
            
            keyButton("←", action: { sendArrowKey(.left) })
            keyButton("↑", action: { sendArrowKey(.up) })
            keyButton("↓", action: { sendArrowKey(.down) })
            keyButton("→", action: { sendArrowKey(.right) })
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.9))
    }
    
    private func keyButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 36, minHeight: 32)
                .background(Color.white.opacity(0.15))
                .cornerRadius(6)
        }
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
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(modifierState.contains(modifier) ? .black : .white)
                .frame(minWidth: 44, minHeight: 32)
                .background(modifierState.contains(modifier) ? Color.cyan : Color.white.opacity(0.15))
                .cornerRadius(6)
        }
    }
    
    private var commandInputView: some View {
        HStack(spacing: 12) {
            TextField("Command...", text: $commandInput)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onSubmit(sendCommand)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
            
            Button {
                toggleKeyboardBar()
            } label: {
                Image(systemName: showKeyboardBar ? "keyboard.chevron.compact.down" : "keyboard.chevron.compact.up")
                    .foregroundColor(.gray)
            }
            
            Button {
                sendCommand()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(commandInput.isEmpty ? .gray : .cyan)
            }
            .disabled(commandInput.isEmpty)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func sendCommand() {
        guard !commandInput.isEmpty else { return }
        
        var command = commandInput
        
        if modifierState.contains(.control) {
            command = applyControlModifier(command)
            modifierState.remove(.control)
        }
        
        Task {
            do {
                try await manager.send(hostId: host.id, command: command + "\n")
                await MainActor.run {
                    commandInput = ""
                    suggestions = []
                }
            } catch {
                print("Error sending command: \(error)")
            }
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
