import SwiftUI

struct SessionConnectionView: View {
    let host: RemoteHost
    @ObservedObject var manager: ConnectionManager

    @State private var password = ""
    @State private var passphrase = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @FocusState private var focusPassword: Bool

    private var isConnected: Bool {
        manager.activeConnections[host.id]?.isConnected ?? false
    }

    private var accent: Color {
        host.colorScheme.liquidAccent
    }

    var body: some View {
        ZStack {
            NeoLiquidBackground()

            if isConnected {
                TerminalSessionView(host: host, manager: manager)
            } else {
                connectionSetupView
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liquidNavigationBackgroundHidden()
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isConnected ? Color.green : NeoLiquidPalette.textMuted)
                        .frame(width: 8, height: 8)
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(NeoLiquidPalette.textPrimary)
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
                            .foregroundColor(NeoLiquidPalette.textSecondary)
                    }
                }
            }
        }
    }

    private var connectionSetupView: some View {
        ScrollView {
            VStack(spacing: 16) {
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
            .padding(.bottom, 20)
        }
    }

    private var hostInfoCard: some View {
        ActionCard(
            title: host.displayName,
            subtitle: "\(host.username)@\(host.hostname):\(host.port)",
            icon: host.colorScheme.glyphSymbol,
            colorScheme: host.colorScheme
        ) {
            HStack(spacing: 8) {
                NeoTagPill(text: host.defaultSessionName, icon: "terminal", accent: accent)
                NeoTagPill(text: host.useKeyAuth ? "Key Auth" : "Password", icon: host.useKeyAuth ? "key.fill" : "lock.fill", accent: accent.opacity(0.8))
            }
        }
    }

    private var passwordAuthCard: some View {
        ActionCard(
            title: "Authentication",
            subtitle: "Enter credentials to open the tmux session",
            icon: "lock.fill",
            colorScheme: host.colorScheme
        ) {
            VStack(spacing: 14) {
                SecureField("Password", text: $password)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($focusPassword)
                    .neoInputSurface(accent: accent)

                Button {
                    connectWithPassword()
                } label: {
                    HStack(spacing: 8) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.horizontal.circle")
                            Text("Connect")
                        }
                    }
                    .font(.headline)
                }
                .buttonStyle(NeoLiquidButtonStyle(tint: accent))
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
            icon: "key.horizontal.fill",
            colorScheme: host.colorScheme
        ) {
            VStack(spacing: 14) {
                if let key = manager.sshKeys.first(where: { $0.id == keyId }) {
                    HStack(spacing: 10) {
                        NeoRoboGlyph(symbol: "key.fill", accent: accent, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.name)
                                .foregroundColor(NeoLiquidPalette.textPrimary)
                            Text(String(key.publicKeyFingerprint.prefix(22)) + "...")
                                .font(.caption2.monospaced())
                                .foregroundColor(NeoLiquidPalette.textMuted)
                        }
                        Spacer()
                        CheckmarkView()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                SecureField("Passphrase (optional)", text: $passphrase)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .neoInputSurface(accent: accent)

                Button {
                    connectWithKey()
                } label: {
                    HStack(spacing: 8) {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.horizontal.circle")
                            Text("Connect with Key")
                        }
                    }
                    .font(.headline)
                }
                .buttonStyle(NeoLiquidButtonStyle(tint: accent))
                .disabled(isConnecting)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraRose, cornerRadius: 20, padding: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(NeoLiquidPalette.auraRose)
                Text(message)
                    .font(.footnote)
                    .foregroundColor(NeoLiquidPalette.textPrimary)
                Spacer()
            }
        }
    }

    private var tipsCard: some View {
        ActionCard(
            title: "Connection Readiness",
            subtitle: "Fast checklist before launch",
            icon: "checkmark.shield",
            colorScheme: host.colorScheme
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TipRow(icon: "checkmark.circle.fill", text: "tmux is installed on remote host", color: .green)
                TipRow(icon: "checkmark.circle.fill", text: "SSH service is reachable", color: .green)
                TipRow(icon: "checkmark.circle.fill", text: "Credentials are never persisted", color: accent)
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
        Image(systemName: "checkmark.seal.fill")
            .font(.title3)
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
