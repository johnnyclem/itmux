import SwiftUI

struct SessionListView: View {
    @StateObject private var manager = ConnectionManager()
    @State private var showingAddHost = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching your screenshots
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.3, blue: 0.5),
                        Color(red: 0.3, green: 0.2, blue: 0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if manager.hosts.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Hosts Configured")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Add a remote host to get started")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button {
                            showingAddHost = true
                        } label: {
                            Label("Add Host", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
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
            .navigationTitle("T-Rex")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddHost) {
                AddHostSheet(manager: manager)
            }
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
                return "Error: \(error)"
            }
        } else if let lastConnected = host.lastConnected {
            let interval = Date().timeIntervalSince(lastConnected)
            if interval < 3600 {
                return "Last seen \(Int(interval / 60))m ago"
            } else if interval < 86400 {
                return "Last seen \(Int(interval / 3600))h ago"
            } else {
                return "Last seen \(Int(interval / 86400))d ago"
            }
        }
        return "Never connected"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            Circle()
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            // Host icon with color
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundColor(host.colorScheme.statusBarColor)
                .frame(width: 40, height: 40)
                .background(host.colorScheme.backgroundColor)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(host.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(host.colorScheme.borderColor, lineWidth: 2)
                )
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes) min, \(seconds) sec"
        } else {
            return "\(seconds) sec"
        }
    }
}
