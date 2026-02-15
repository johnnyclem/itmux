import SwiftUI

public struct SessionListView: View {
    @StateObject private var manager = ConnectionManager()
    @State private var showingAddHost = false
    @State private var showingKeyManager = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
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
                
                if manager.hosts.isEmpty {
                    emptyStateView
                } else {
                    hostListView
                }
            }
            .navigationTitle("iTMUX")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.cyan)
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            showingKeyManager = true
                        } label: {
                            Label("SSH Keys", systemImage: "key.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showingAddHost) {
                AddHostSheet(manager: manager)
            }
            .sheet(isPresented: $showingKeyManager) {
                SSHKeyManagerView(manager: manager)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 72))
                .foregroundColor(.cyan.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("iTMUX")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                Text("Terminal Multiplexer Remote")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                Text("No Hosts Configured")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text("Add a remote host running tmux to get started")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            Button {
                showingAddHost = true
            } label: {
                Label("Add Host", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.cyan)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    private var hostListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(manager.hosts) { host in
                    NavigationLink(destination: SessionConnectionView(host: host, manager: manager)) {
                        SessionCard(host: host, connectionState: manager.activeConnections[host.id])
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct SessionCard: View {
    let host: RemoteHost
    let connectionState: ConnectionManager.ConnectionState?
    
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
            } else if let error = state.error {
                return "Error"
            }
        } else if let lastConnected = host.lastConnected {
            let interval = Date().timeIntervalSince(lastConnected)
            if interval < 3600 {
                return "Last: \(Int(interval / 60))m ago"
            } else if interval < 86400 {
                return "Last: \(Int(interval / 3600))h ago"
            } else {
                return "Last: \(Int(interval / 86400))d ago"
            }
        }
        return "Never connected"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(isConnected ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
            
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundColor(host.colorScheme.statusBarColor)
                .frame(width: 44, height: 44)
                .background(host.colorScheme.backgroundColor)
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isConnected {
                        Text("\(connectionState?.activePanes ?? 0)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(host.username)
                    Text("@")
                    Text(host.hostname)
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(isConnected ? .green : .gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(host.colorScheme.borderColor, lineWidth: 1.5)
                )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    SessionListView()
}
