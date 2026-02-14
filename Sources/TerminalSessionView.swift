import SwiftUI

struct TerminalSessionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager
    
    @State private var commandInput = ""
    @State private var suggestions: [String] = []
    @FocusState private var isInputFocused: Bool
    
    private var panes: [PaneState] {
        manager.getPanes(for: host.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal view
            if let firstPane = panes.first {
                TerminalContainerView(
                    pane: firstPane,
                    hostname: host.displayName,
                    colorScheme: host.colorScheme
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Initializing terminal...")
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Autocomplete toolbar (appears above keyboard)
            if !suggestions.isEmpty {
                AutocompleteToolbar(
                    suggestions: suggestions,
                    onSelect: { suggestion in
                        commandInput = suggestion
                    },
                    onAccept: {
                        if let first = suggestions.first {
                            commandInput = first
                            sendCommand()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Command input
            CommandInputView(
                text: $commandInput,
                placeholder: "Type a command...",
                isFocused: $isInputFocused,
                onSubmit: sendCommand
            )
        }
        .animation(.spring(response: 0.3), value: suggestions)
        .onChange(of: commandInput) { newValue in
            updateSuggestions(for: newValue)
        }
        .onAppear {
            isInputFocused = true
        }
    }
    
    private func sendCommand() {
        guard !commandInput.isEmpty else { return }
        
        Task {
            do {
                try await manager.send(hostId: host.id, command: commandInput)
                await MainActor.run {
                    commandInput = ""
                    suggestions = []
                }
            } catch {
                print("Error sending command: \(error)")
            }
        }
    }
    
    private func updateSuggestions(for input: String) {
        guard !input.isEmpty else {
            suggestions = []
            return
        }
        
        // Simple autocomplete for now - you can expand this
        var newSuggestions: [String] = []
        
        // Command completions
        if !input.contains(" ") {
            let commands = ["ls", "cd", "git", "vim", "nano", "cat", "grep", "find", "ssh", "tmux"]
            newSuggestions = commands.filter { $0.hasPrefix(input) }
        }
        
        // Common command patterns
        if input.hasPrefix("git ") {
            let gitCommands = ["git status", "git add .", "git commit", "git push", "git pull", "git log"]
            newSuggestions = gitCommands.filter { $0.hasPrefix(input) }
        }
        
        if input.hasPrefix("cd ") {
            newSuggestions = ["cd ~", "cd ..", "cd ~/Documents", "cd ~/Desktop"]
                .filter { $0.hasPrefix(input) }
        }
        
        suggestions = Array(newSuggestions.prefix(5))
    }
}

struct TerminalContainerView: View {
    let pane: PaneState
    let hostname: String
    let colorScheme: HostColorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Host indicator bar
            HStack {
                Text(hostname)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(pane.workingDirectory)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colorScheme.statusBarColor)
            
            // Terminal view
            TerminalView(
                paneId: pane.id,
                colorScheme: colorScheme,
                renderer: pane.renderer
            )
            .background(colorScheme.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme.borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

struct AutocompleteToolbar: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    let onAccept: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconFor(suggestion))
                                .font(.caption)
                            Text(suggestion)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                        )
                        .foregroundColor(.white)
                    }
                }
                
                // Accept button (like tab-complete + enter)
                Button {
                    onAccept()
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
    }
    
    private func iconFor(_ suggestion: String) -> String {
        if suggestion.contains("/") { return "folder" }
        if suggestion.hasPrefix("git ") { return "arrow.triangle.branch" }
        if suggestion.hasPrefix("cd ") { return "arrow.right" }
        return "terminal"
    }
}

struct CommandInputView: View {
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            Button {
                // Voice input placeholder
            } label: {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
        )
        .padding()
    }
}
