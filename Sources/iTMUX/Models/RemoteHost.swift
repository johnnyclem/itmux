import Foundation
import SwiftUI

public enum HostColorScheme: String, CaseIterable, Codable {
    case ocean
    case forest
    case sunset
    case midnight
    case ruby
    case emerald
    
    public var statusBarColor: Color {
        switch self {
        case .ocean: return Color.blue
        case .forest: return Color.green
        case .sunset: return Color.orange
        case .midnight: return Color.purple
        case .ruby: return Color.red
        case .emerald: return Color.teal
        }
    }
    
    public var borderColor: Color {
        statusBarColor.opacity(0.6)
    }
    
    public var backgroundColor: Color {
        switch self {
        case .ocean: return Color.blue.opacity(0.05)
        case .forest: return Color.green.opacity(0.05)
        case .sunset: return Color.orange.opacity(0.05)
        case .midnight: return Color.purple.opacity(0.05)
        case .ruby: return Color.red.opacity(0.05)
        case .emerald: return Color.teal.opacity(0.05)
        }
    }
    
    public var displayName: String {
        rawValue.capitalized
    }
    
    public static func random() -> HostColorScheme {
        allCases.randomElement()!
    }
}

public struct RemoteHost: Identifiable, Codable {
    public let id: UUID
    public var displayName: String
    public let hostname: String
    public let username: String
    public var port: Int
    public var colorScheme: HostColorScheme
    public var lastConnected: Date?
    public var defaultSessionName: String
    public var useKeyAuth: Bool
    public var keyId: UUID?
    
    public init(
        id: UUID = UUID(),
        displayName: String,
        hostname: String,
        username: String,
        port: Int = 22,
        colorScheme: HostColorScheme? = nil,
        defaultSessionName: String = "itmux",
        useKeyAuth: Bool = false,
        keyId: UUID? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.hostname = hostname
        self.username = username
        self.port = port
        self.colorScheme = colorScheme ?? .random()
        self.defaultSessionName = defaultSessionName
        self.useKeyAuth = useKeyAuth
        self.keyId = keyId
    }
}

public struct SSHKey: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public let privateKeyPEM: Data
    public var publicKeyFingerprint: String
    public var createdAt: Date
    public var lastUsed: Date?
    
    public init(id: UUID = UUID(), name: String, privateKeyPEM: Data, publicKeyFingerprint: String) {
        self.id = id
        self.name = name
        self.privateKeyPEM = privateKeyPEM
        self.publicKeyFingerprint = publicKeyFingerprint
        self.createdAt = Date()
        self.lastUsed = nil
    }
}

struct PaneState {
    let id: String
    var windowId: String?
    var buffer: Data = Data()
    var renderer: TerminalRenderer
    var workingDirectory: String = "~"
    var title: String = ""
    var isActive: Bool = false
    var dimensions: (rows: Int, cols: Int) = (24, 80)
    
    init(id: String, windowId: String? = nil, columns: Int = 80, rows: Int = 24) {
        self.id = id
        self.windowId = windowId
        self.renderer = TerminalRenderer(columns: columns, rows: rows)
    }
}

struct TmuxWindow: Identifiable {
    let id: String
    var name: String
    var sessionId: String
    var paneIds: [String]
    var activePaneId: String?
    var layout: String
    var width: Int
    var height: Int
    
    init(id: String, name: String, sessionId: String) {
        self.id = id
        self.name = name
        self.sessionId = sessionId
        self.paneIds = []
        self.activePaneId = nil
        self.layout = ""
        self.width = 80
        self.height = 24
    }
}

struct TmuxSession: Identifiable {
    let id: String
    var name: String
    var windowIds: [String]
    var activeWindowId: String?
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.windowIds = []
        self.activeWindowId = nil
    }
}
