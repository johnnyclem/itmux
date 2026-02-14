import SwiftUI

struct SessionConnectionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager
    
    @State private var password = ""
    @State private var isConnecting = false
    @State private var showPasswordInput = false
    @Environment(\.dismiss) private var dismiss
    
    private var isConnected: Bool {
        manager.activeConnections[host.id]?.isConnected ?? false
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.5),
                    Color(red: 0.3, green: 0.2, blue: 0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isConnected {
                TerminalSessionView(host: host, manager: manager)
            } else {
                ConnectionSetupView(
                    host: host,
                    password: $password,
                    isConnecting: $isConnecting,
                    showPasswordInput: $showPasswordInput,
                    onConnect: connectToHost
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(isConnected ? "ONLINE" : "OFFLINE")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private func connectToHost() {
        isConnecting = true
        Task {
            do {
                try await manager.connect(hostId: host.id, password: password)
                await MainActor.run {
                    isConnecting = false
                    password = ""
                    showPasswordInput = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                }
            }
        }
    }
}

struct ConnectionSetupView: View {
    let host: RemoteHost
    @Binding var password: String
    @Binding var isConnecting: Bool
    @Binding var showPasswordInput: Bool
    let onConnect: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Host info card
                ActionCard(
                    title: "Connect to \(host.displayName)",
                    subtitle: "\(host.username)@\(host.hostname):\(host.port)",
                    icon: "server.rack",
                    colorScheme: host.colorScheme
                ) {
                    Button {
                        showPasswordInput.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Enter Password")
                            Spacer()
                            Image(systemName: showPasswordInput ? "chevron.up" : "chevron.down")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                
                // Password input card (expandable)
                if showPasswordInput {
                    ActionCard(
                        title: "Authentication",
                        subtitle: "Enter your SSH password",
                        icon: "lock.fill",
                        colorScheme: host.colorScheme
                    ) {
                        VStack(spacing: 12) {
                            SecureField("Password", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            Button {
                                onConnect()
                            } label: {
                                HStack {
                                    if isConnecting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Connect")
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .disabled(password.isEmpty || isConnecting)
                            .opacity(password.isEmpty || isConnecting ? 0.5 : 1)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Connection help card
                ActionCard(
                    title: "Connection Tips",
                    subtitle: nil,
                    icon: "info.circle.fill",
                    colorScheme: host.colorScheme
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        TipRow(icon: "checkmark.circle", text: "Make sure tmux is installed on the remote host")
                        TipRow(icon: "checkmark.circle", text: "SSH must be enabled and accessible")
                        TipRow(icon: "checkmark.circle", text: "Your password is never stored")
                    }
                }
            }
            .padding()
        }
        .animation(.spring(), value: showPasswordInput)
    }
}

struct ActionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let colorScheme: HostColorScheme
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(colorScheme.statusBarColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            
            // Content
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme.borderColor.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
