import SwiftUI

public struct SessionListView: View {
    @StateObject private var manager = ConnectionManager()
    @State private var showingAddHost = false
    @State private var showingKeyManager = false

    public init() {}

    private var connectedHosts: Int {
        manager.activeConnections.values.filter { $0.isConnected }.count
    }

    private var totalPanes: Int {
        manager.activeConnections.values.map(\.activePanes).reduce(0, +)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                NeoLiquidBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        commandCenterHero

                        if manager.hosts.isEmpty {
                            emptyStateView
                        } else {
                            hostListView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("iTMUX")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHost = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(NeoLiquidPalette.auraCyan)
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            showingKeyManager = true
                        } label: {
                            Label("SSH Keys", systemImage: "key.horizontal.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(NeoLiquidPalette.textSecondary)
                    }
                }
            }
            .liquidNavigationBackgroundHidden()
            .sheet(isPresented: $showingAddHost) {
                AddHostSheet(manager: manager)
            }
            .sheet(isPresented: $showingKeyManager) {
                SSHKeyManagerView(manager: manager)
            }
        }
    }

    private var commandCenterHero: some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraCyan, cornerRadius: 26, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Neo Command Sanctuary")
                            .font(.title3.weight(.bold))
                            .foregroundColor(NeoLiquidPalette.textPrimary)
                        Text("Remote tmux operations with focused iPhone workflow.")
                            .font(.caption)
                            .foregroundColor(NeoLiquidPalette.textSecondary)
                    }

                    Spacer()

                    NeoRoboGlyph(symbol: "sparkles", accent: NeoLiquidPalette.auraCyan, size: 46)
                }

                HStack(spacing: 8) {
                    NeoTagPill(text: "\(manager.hosts.count) Hosts", icon: "server.rack", accent: NeoLiquidPalette.auraMint)
                    NeoTagPill(text: "\(connectedHosts) Live", icon: "waveform.path.ecg", accent: NeoLiquidPalette.auraCyan)
                    NeoTagPill(text: "\(totalPanes) Panes", icon: "rectangle.split.3x1.fill", accent: NeoLiquidPalette.auraRose)
                }
            }
        }
    }

    private var emptyStateView: some View {
        NeoGlassCard(accent: NeoLiquidPalette.auraRose, cornerRadius: 26, padding: 22) {
            VStack(spacing: 18) {
                NeoRoboGlyph(symbol: "moon.stars", accent: NeoLiquidPalette.auraRose, size: 70)

                VStack(spacing: 6) {
                    Text("No Hosts Connected Yet")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(NeoLiquidPalette.textPrimary)
                    Text("Summon your first remote machine and enter focus mode.")
                        .font(.subheadline)
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showingAddHost = true
                } label: {
                    Label("Add First Host", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(NeoLiquidButtonStyle(tint: NeoLiquidPalette.auraCyan))
            }
        }
    }

    private var hostListView: some View {
        LazyVStack(spacing: 14) {
            ForEach(manager.hosts) { host in
                NavigationLink(destination: SessionConnectionView(host: host, manager: manager)) {
                    SessionCard(host: host, connectionState: manager.activeConnections[host.id])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SessionCard: View {
    let host: RemoteHost
    let connectionState: ConnectionManager.ConnectionState?
    @State private var pulseOnline = false

    private var isConnected: Bool {
        connectionState?.isConnected ?? false
    }

    private var statusText: String {
        if let state = connectionState {
            if state.isConnected {
                if let duration = state.duration {
                    return formatDuration(duration)
                }
                return "Connected"
            }
            if let error = state.error {
                let line = error.split(separator: "\n").first.map(String.init) ?? "Error"
                return "Error: \(line)"
            }
        } else if let lastConnected = host.lastConnected {
            let interval = Date().timeIntervalSince(lastConnected)
            if interval < 3600 {
                return "Last: \(Int(interval / 60))m ago"
            }
            if interval < 86400 {
                return "Last: \(Int(interval / 3600))h ago"
            }
            return "Last: \(Int(interval / 86400))d ago"
        }
        return "Never connected"
    }

    var body: some View {
        NeoGlassCard(accent: host.colorScheme.liquidAccent, cornerRadius: 20, padding: 15) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill((isConnected ? Color.green : Color.gray).opacity(0.28))
                        .frame(width: 20, height: 20)
                        .scaleEffect(isConnected && pulseOnline ? 1.24 : 0.94)
                        .opacity(isConnected ? 1 : 0.65)
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray.opacity(0.75))
                        .frame(width: 9, height: 9)
                }

                NeoRoboGlyph(symbol: host.colorScheme.glyphSymbol, accent: host.colorScheme.liquidAccent, size: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(host.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(NeoLiquidPalette.textPrimary)

                        if isConnected {
                            NeoTagPill(
                                text: "\(connectionState?.activePanes ?? 0) panes",
                                icon: "rectangle.split.3x1.fill",
                                accent: host.colorScheme.liquidAccent
                            )
                        }
                    }

                    Text("\(host.username)@\(host.hostname):\(host.port)")
                        .font(.caption.monospaced())
                        .foregroundColor(NeoLiquidPalette.textSecondary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(isConnected ? host.colorScheme.liquidAccent : NeoLiquidPalette.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(NeoLiquidPalette.textMuted)
            }
        }
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseOnline)
        .onAppear {
            pulseOnline = true
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

#Preview {
    SessionListView()
}
