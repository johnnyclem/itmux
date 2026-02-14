import Foundation

@MainActor
class ConnectionManager: ObservableObject {
    @Published var hosts: [RemoteHost] = []
    @Published var activeConnections: [UUID: ConnectionState] = [:]
    
    private var connections: [UUID: SSHConnection] = [:]
    private var paneStates: [UUID: [String: PaneState]] = [:]
    
    struct ConnectionState {
        var isConnected: Bool
        var connectedAt: Date?
        var error: String?
        
        var duration: TimeInterval? {
            guard let connectedAt = connectedAt else { return nil }
            return Date().timeIntervalSince(connectedAt)
        }
    }
    
    init() {
        loadHosts()
    }
    
    func addHost(_ host: RemoteHost) {
        hosts.append(host)
        saveHosts()
    }
    
    func removeHost(_ id: UUID) {
        Task {
            await disconnect(hostId: id)
        }
        hosts.removeAll { $0.id == id }
        saveHosts()
    }
    
    func updateHost(_ host: RemoteHost) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
            saveHosts()
        }
    }
    
    func connect(hostId: UUID, password: String, sessionName: String = "trex") async throws {
        guard let hostIndex = hosts.firstIndex(where: { $0.id == hostId }) else {
            throw SSHError.connectionFailed("Host not found")
        }
        
        let host = hosts[hostIndex]
        
        await MainActor.run {
            activeConnections[hostId] = ConnectionState(
                isConnected: false,
                connectedAt: nil,
                error: nil
            )
        }
        
        let connection = SSHConnection(
            host: host.hostname,
            port: host.port,
            username: host.username
        )
        
        do {
            try await connection.connect(password: password)
            try await connection.startTmux(sessionName: sessionName)
            
            await connection.onMessage { [weak self] message in
                await self?.handleMessage(hostId: hostId, message: message)
            }
            
            await MainActor.run {
                connections[hostId] = connection
                activeConnections[hostId] = ConnectionState(
                    isConnected: true,
                    connectedAt: Date(),
                    error: nil
                )
                hosts[hostIndex].lastConnected = Date()
                saveHosts()
            }
            
        } catch {
            await MainActor.run {
                activeConnections[hostId] = ConnectionState(
                    isConnected: false,
                    connectedAt: nil,
                    error: error.localizedDescription
                )
            }
            throw error
        }
    }
    
    func send(hostId: UUID, command: String) async throws {
        guard let connection = connections[hostId] else {
            throw SSHError.disconnected
        }
        
        try await connection.send(command)
    }
    
    func disconnect(hostId: UUID) async {
        if let connection = connections[hostId] {
            await connection.disconnect()
            await MainActor.run {
                connections.removeValue(forKey: hostId)
                activeConnections.removeValue(forKey: hostId)
                paneStates.removeValue(forKey: hostId)
            }
        }
    }
    
    func getPanes(for hostId: UUID) -> [PaneState] {
        guard let panes = paneStates[hostId] else { return [] }
        return Array(panes.values)
    }
    
    private func handleMessage(hostId: UUID, message: TmuxControlMessage) async {
        await MainActor.run {
            var panes = paneStates[hostId] ?? [:]
            
            switch message {
            case .output(let paneId, let data):
                if panes[paneId] == nil {
                    panes[paneId] = PaneState(id: paneId)
                }
                
                Task {
                    if let paneState = panes[paneId] {
                        _ = await paneState.renderer.process(data)
                        panes[paneId] = paneState
                        paneStates[hostId] = panes
                        objectWillChange.send()
                    }
                }
                
            case .layoutChange(let sessionId, let layout):
                print("Layout changed: \(sessionId) -> \(layout)")
                
            case .windowAdd(let windowId):
                print("Window added: \(windowId)")
                
            case .windowClose(let windowId):
                print("Window closed: \(windowId)")
                
            case .sessionChanged(let sessionId, let sessionName):
                print("Session changed: \(sessionId) (\(sessionName))")
                
            case .exit(let reason):
                print("Tmux exited: \(reason)")
                Task {
                    await disconnect(hostId: hostId)
                }
                
            case .unknown(let line):
                print("Unknown control message: \(line)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(encoded, forKey: "trex.hosts")
        }
    }
    
    private func loadHosts() {
        if let data = UserDefaults.standard.data(forKey: "trex.hosts"),
           let decoded = try? JSONDecoder().decode([RemoteHost].self, from: data) {
            hosts = decoded
        }
    }
}
