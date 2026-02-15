import SwiftUI

struct SessionConnectionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager
    
    @State private var password = ""
    @State private var passphrase = ""
    @State private var isConnecting = false
    @State private var showPasswordInput = false
    @State private var errorMessage: String?
    @State private var selectedKeyId: UUID?
    @FocusState private var focusPassword: Bool
    @Environment(\.dismiss) private var dismiss
    
    private var isConnected: Bool {
        manager.activeConnections[host.id]?.isConnected ?? false
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if isConnected {
                TerminalSessionView(host: host, manager: manager)
            } else {
                connectionSetupView
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            if isConnected {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive) {
                            Task {
                                await manager.disconnect(hostId: host.id)
                            }
                        } label: {
                            Label("Disconnect", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private var connectionSetupView: some View {
        ScrollView {
            VStack(spacing: 20) {
                hostInfoCard
                
                if host.useKeyAuth, let keyId = host.keyId {
                    keyAuthCard(keyId: keyId)
                } else {
                    passwordAuthCard
                }
                
                if let error = errorMessage {
                    errorCard(error)
                }
                
                tipsCard
            }
            .padding()
        }
    }
    
    private var hostInfoCard: some View {
        ActionCard(
            title: host.displayName,
            subtitle: "\(host.username)@\(host.hostname):\(host.port)",
            icon: "server.rack",
            colorScheme: host.colorScheme
        ) {
            EmptyView()
        }
    }
    
    private var passwordAuthCard: some View {
        ActionCard(
            title: "Authentication",
            subtitle: host.useKeyAuth ? "SSH Key" : "Password",
            icon: "lock.fill",
            colorScheme: host.colorScheme
        ) {
            VStack(spacing: 16) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusPassword)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button {
                    connectWithPassword()
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
                    .padding(14)
                    .background(password.isEmpty || isConnecting ? Color.gray : Color.cyan)
                    .cornerRadius(10)
                }
                .disabled(password.isEmpty || isConnecting)
            }
        }
        .onAppear {
            focusPassword = true
        }
    }
    
    private func keyAuthCard(keyId: UUID) -> some View {
        ActionCard(
            title: "SSH Key Authentication",
            subtitle: manager.sshKeys.first(where: { $0.id == keyId })?.name ?? "Unknown Key",
            icon: "key.fill",
            colorScheme: host.colorScheme
        ) {
            VStack(spacing: 16) {
                if let key = manager.sshKeys.first(where: { $0.id == keyId }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading) {
                            Text(key.name)
                                .foregroundColor(.white)
                            Text(String(key.publicKeyFingerprint.prefix(16)) + "...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        CheckmarkView()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                
                SecureField("Passphrase (optional)", text: $passphrase)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                
                Button {
                    connectWithKey()
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
                    .padding(14)
                    .background(isConnecting ? Color.gray : Color.cyan)
                    .cornerRadius(10)
                }
                .disabled(isConnecting)
            }
        }
    }
    
    private func errorCard(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var tipsCard: some View {
        ActionCard(
            title: "Requirements",
            subtitle: nil,
            icon: "info.circle.fill",
            colorScheme: host.colorScheme
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "checkmark.circle", text: "tmux must be installed on remote host", color: .green)
                TipRow(icon: "checkmark.circle", text: "SSH server must be running", color: .green)
                TipRow(icon: "checkmark.circle", text: "Your password is never stored", color: .cyan)
            }
        }
    }
    
    private func connectWithPassword() {
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await manager.connect(
                    hostId: host.id,
                    password: password,
                    sessionName: host.defaultSessionName
                )
                await MainActor.run {
                    isConnecting = false
                    password = ""
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func connectWithKey() {
        guard let keyId = host.keyId else { return }
        
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await manager.connectWithKey(
                    hostId: host.id,
                    keyId: keyId,
                    passphrase: passphrase.isEmpty ? nil : passphrase,
                    sessionName: host.defaultSessionName
                )
                await MainActor.run {
                    isConnecting = false
                    passphrase = ""
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CheckmarkView: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
    }
}

#Preview {
    NavigationStack {
        SessionConnectionView(
            host: RemoteHost(
                displayName: "Test Server",
                hostname: "192.168.1.100",
                username: "user"
            ),
            manager: ConnectionManager()
        )
    }
}
