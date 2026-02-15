import Foundation

@MainActor
public class ConnectionManager: ObservableObject {
    @Published public var hosts: [RemoteHost] = []
    @Published public var activeConnections: [UUID: ConnectionState] = [:]
    @Published public var sshKeys: [SSHKey] = []
    
    private var connections: [UUID: SSHConnection] = [:]
    private var paneStates: [UUID: [String: PaneState]] = [:]
    private var windowStates: [UUID: [String: TmuxWindow]] = [:]
    private var sessionStates: [UUID: [String: TmuxSession]] = [:]
    
    public struct ConnectionState: Equatable {
        public var isConnected: Bool
        public var connectedAt: Date?
        public var error: String?
        public var currentSession: String?
        public var activePanes: Int
        public var activeWindows: Int
        
        public var duration: TimeInterval? {
            guard let connectedAt = connectedAt else { return nil }
            return Date().timeIntervalSince(connectedAt)
        }
        
        public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            lhs.isConnected == rhs.isConnected &&
            lhs.connectedAt == rhs.connectedAt &&
            lhs.error == rhs.error &&
            lhs.currentSession == rhs.currentSession &&
            lhs.activePanes == rhs.activePanes &&
            lhs.activeWindows == rhs.activeWindows
        }
    }
    
    init() {
        loadHosts()
        loadKeys()
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
    
    func connect(hostId: UUID, password: String, sessionName: String = "itmux") async throws {
        guard let hostIndex = hosts.firstIndex(where: { $0.id == hostId }) else {
            throw SSHError.connectionFailed("Host not found")
        }
        
        let host = hosts[hostIndex]
        
        activeConnections[hostId] = ConnectionState(
            isConnected: false,
            connectedAt: nil,
            error: nil,
            currentSession: nil,
            activePanes: 0,
            activeWindows: 0
        )
        
        let connection = SSHConnection(
            host: host.hostname,
            port: host.port,
            username: host.username
        )
        
        do {
            try await connection.connect(authMethod: .password(password))
            
            await connection.onMessage { [weak self] message in
                await self?.handleMessage(hostId: hostId, message: message)
            }
            
            try await connection.startTmux(sessionName: sessionName)
            
            connections[hostId] = connection
            activeConnections[hostId] = ConnectionState(
                isConnected: true,
                connectedAt: Date(),
                error: nil,
                currentSession: sessionName,
                activePanes: 0,
                activeWindows: 0
            )
            hosts[hostIndex].lastConnected = Date()
            saveHosts()
            
        } catch {
            activeConnections[hostId] = ConnectionState(
                isConnected: false,
                connectedAt: nil,
                error: error.localizedDescription,
                currentSession: nil,
                activePanes: 0,
                activeWindows: 0
            )
            throw error
        }
    }
    
    func connectWithKey(hostId: UUID, keyId: UUID, passphrase: String? = nil, sessionName: String = "itmux") async throws {
        guard let hostIndex = hosts.firstIndex(where: { $0.id == hostId }) else {
            throw SSHError.connectionFailed("Host not found")
        }
        
        guard let key = sshKeys.first(where: { $0.id == keyId }) else {
            throw SSHError.invalidKey("Key not found")
        }
        
        let host = hosts[hostIndex]
        
        activeConnections[hostId] = ConnectionState(
            isConnected: false,
            connectedAt: nil,
            error: nil,
            currentSession: nil,
            activePanes: 0,
            activeWindows: 0
        )
        
        let connection = SSHConnection(
            host: host.hostname,
            port: host.port,
            username: host.username
        )
        
        guard let keyPEM = String(data: key.privateKeyPEM, encoding: .utf8) else {
            throw SSHError.invalidKey("Invalid key data")
        }
        
        do {
            try await connection.connect(authMethod: .privateKey(keyPEM, passphrase: passphrase))
            
            await connection.onMessage { [weak self] message in
                await self?.handleMessage(hostId: hostId, message: message)
            }
            
            try await connection.startTmux(sessionName: sessionName)
            
            connections[hostId] = connection
            activeConnections[hostId] = ConnectionState(
                isConnected: true,
                connectedAt: Date(),
                error: nil,
                currentSession: sessionName,
                activePanes: 0,
                activeWindows: 0
            )
            hosts[hostIndex].lastConnected = Date()
            saveHosts()
            
        } catch {
            activeConnections[hostId] = ConnectionState(
                isConnected: false,
                connectedAt: nil,
                error: error.localizedDescription,
                currentSession: nil,
                activePanes: 0,
                activeWindows: 0
            )
            throw error
        }
    }
    
    func send(hostId: UUID, command: String) async throws {
        guard let connection = connections[hostId] else {
            throw SSHError.disconnected
        }
        
        try await connection.send(command)
    }
    
    func sendTmuxCommand(hostId: UUID, command: TmuxCommand) async throws {
        guard let connection = connections[hostId] else {
            throw SSHError.disconnected
        }
        
        try await connection.send(command.commandString + "\n")
    }
    
    func disconnect(hostId: UUID) async {
        if let connection = connections[hostId] {
            await connection.disconnect()
            connections.removeValue(forKey: hostId)
            activeConnections.removeValue(forKey: hostId)
            paneStates.removeValue(forKey: hostId)
            windowStates.removeValue(forKey: hostId)
            sessionStates.removeValue(forKey: hostId)
        }
    }
    
    func getPanes(for hostId: UUID) -> [PaneState] {
        guard let panes = paneStates[hostId] else { return [] }
        return Array(panes.values)
    }
    
    func getPane(for hostId: UUID, paneId: String) -> PaneState? {
        return paneStates[hostId]?[paneId]
    }
    
    func getWindows(for hostId: UUID) -> [TmuxWindow] {
        guard let windows = windowStates[hostId] else { return [] }
        return Array(windows.values)
    }
    
    func getActivePane(for hostId: UUID) -> PaneState? {
        guard let panes = paneStates[hostId] else { return nil }
        return panes.values.first { $0.isActive }
    }
    
    private func handleMessage(hostId: UUID, message: TmuxControlMessage) async {
        var panes = paneStates[hostId] ?? [:]
        var windows = windowStates[hostId] ?? [:]
        var sessions = sessionStates[hostId] ?? [:]
        
        switch message {
        case .output(let paneId, let data):
            if panes[paneId] == nil {
                panes[paneId] = PaneState(id: paneId)
            }
            
            if var paneState = panes[paneId] {
                _ = await paneState.renderer.process(data)
                panes[paneId] = paneState
            }
            
            paneStates[hostId] = panes
            await MainActor.run { objectWillChange.send() }
            
        case .layoutChange(let windowId, let layout):
            if var window = windows[windowId] {
                window.layout = layout
                windows[windowId] = window
                
                let parsedLayout = TmuxLayoutParser.parseLayout(layout)
                for paneLayout in parsedLayout {
                    if var pane = panes[paneLayout.paneId] {
                        pane.dimensions = (paneLayout.height, paneLayout.width)
                        panes[paneLayout.paneId] = pane
                    }
                }
            }
            windowStates[hostId] = windows
            paneStates[hostId] = panes
            
        case .windowAdd(let windowId, let windowName):
            let session = sessions.values.first
            let window = TmuxWindow(
                id: windowId,
                name: windowName ?? "",
                sessionId: session?.id ?? ""
            )
            windows[windowId] = window
            windowStates[hostId] = windows
            updateConnectionState(hostId: hostId)
            
        case .windowClose(let windowId):
            windows.removeValue(forKey: windowId)
            for (paneId, pane) in panes where pane.windowId == windowId {
                panes.removeValue(forKey: paneId)
            }
            windowStates[hostId] = windows
            paneStates[hostId] = panes
            updateConnectionState(hostId: hostId)
            
        case .windowRenamed(let windowId, let name):
            if var window = windows[windowId] {
                window.name = name
                windows[windowId] = window
            }
            windowStates[hostId] = windows
            
        case .sessionChanged(let sessionId, let sessionName):
            var session = sessions[sessionId] ?? TmuxSession(id: sessionId, name: sessionName)
            session.name = sessionName
            sessions[sessionId] = session
            sessionStates[hostId] = sessions
            
            if var state = activeConnections[hostId] {
                state.currentSession = sessionName
                activeConnections[hostId] = state
            }
            
        case .sessionClosed(let sessionId):
            sessions.removeValue(forKey: sessionId)
            sessionStates[hostId] = sessions
            
        case .paneMode(let paneId, let mode):
            print("Pane \(paneId) entered mode: \(mode)")
            
        case .paneFocusIn(let paneId):
            for (id, var pane) in panes {
                pane.isActive = (id == paneId)
                panes[id] = pane
            }
            paneStates[hostId] = panes
            
        case .paneFocusOut(let paneId):
            if var pane = panes[paneId] {
                pane.isActive = false
                panes[paneId] = pane
            }
            paneStates[hostId] = panes
            
        case .paneSetClipboard(let paneId, let buffer):
            if let buffer = buffer, let text = String(data: buffer, encoding: .utf8) {
                #if os(iOS)
                UIPasteboard.general.string = text
                #endif
            }
            
        case .exit(let reason):
            print("Tmux exited: \(reason)")
            await disconnect(hostId: hostId)
            
        case .features(let features):
            print("Tmux features: \(features)")
            
        case .subscriptions(let subs):
            print("Tmux subscriptions: \(subs)")
            
        case .unknown(let line):
            print("Unknown control message: \(line)")
        }
    }
    
    private func updateConnectionState(hostId: UUID) {
        if var state = activeConnections[hostId] {
            state.activePanes = paneStates[hostId]?.count ?? 0
            state.activeWindows = windowStates[hostId]?.count ?? 0
            activeConnections[hostId] = state
        }
    }
    
    func addSSHKey(name: String, privateKeyPEM: Data, publicKeyFingerprint: String) {
        let key = SSHKey(name: name, privateKeyPEM: privateKeyPEM, publicKeyFingerprint: publicKeyFingerprint)
        sshKeys.append(key)
        saveKeys()
    }
    
    func removeSSHKey(_ id: UUID) {
        sshKeys.removeAll { $0.id == id }
        saveKeys()
    }
    
    private func saveHosts() {
        if let encoded = try? JSONEncoder().encode(hosts) {
            UserDefaults.standard.set(encoded, forKey: "itmux.hosts")
        }
    }
    
    private func loadHosts() {
        if let data = UserDefaults.standard.data(forKey: "itmux.hosts"),
           let decoded = try? JSONDecoder().decode([RemoteHost].self, from: data) {
            hosts = decoded
        }
    }
    
    private func saveKeys() {
        if let encoded = try? JSONEncoder().encode(sshKeys) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrAccount as String: "itmux.sshKeys",
                kSecValueData as String: encoded
            ]
            
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    private func loadKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrAccount as String: "itmux.sshKeys",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data,
           let decoded = try? JSONDecoder().decode([SSHKey].self, from: data) {
            sshKeys = decoded
        }
    }
}
