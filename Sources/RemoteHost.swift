import Foundation
import SwiftUI

enum HostColorScheme: String, CaseIterable, Codable {
    case ocean
    case forest
    case sunset
    case midnight
    case ruby
    case emerald
    
    var statusBarColor: Color {
        switch self {
        case .ocean: return Color.blue
        case .forest: return Color.green
        case .sunset: return Color.orange
        case .midnight: return Color.purple
        case .ruby: return Color.red
        case .emerald: return Color.teal
        }
    }
    
    var borderColor: Color {
        statusBarColor.opacity(0.6)
    }
    
    var backgroundColor: Color {
        switch self {
        case .ocean: return Color.blue.opacity(0.05)
        case .forest: return Color.green.opacity(0.05)
        case .sunset: return Color.orange.opacity(0.05)
        case .midnight: return Color.purple.opacity(0.05)
        case .ruby: return Color.red.opacity(0.05)
        case .emerald: return Color.teal.opacity(0.05)
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    static func random() -> HostColorScheme {
        allCases.randomElement()!
    }
}

struct RemoteHost: Identifiable, Codable {
    let id: UUID
    var displayName: String
    let hostname: String
    let username: String
    var port: Int
    var colorScheme: HostColorScheme
    var lastConnected: Date?
    
    init(
        id: UUID = UUID(),
        displayName: String,
        hostname: String,
        username: String,
        port: Int = 22,
        colorScheme: HostColorScheme? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.hostname = hostname
        self.username = username
        self.port = port
        self.colorScheme = colorScheme ?? .random()
    }
}

struct PaneState {
    let id: String
    var buffer: Data = Data()
    var renderer: TerminalRenderer
    var workingDirectory: String = "~"
    
    init(id: String, columns: Int = 80, rows: Int = 24) {
        self.id = id
        self.renderer = TerminalRenderer(columns: columns, rows: rows)
    }
}
