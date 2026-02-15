import Foundation
import Crypto

enum SSHError: Error, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case channelFailed(String)
    case disconnected
    case invalidKey(String)
    case handshakeFailed(String)
    case timeout
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .authenticationFailed(let msg): return "Authentication failed: \(msg)"
        case .channelFailed(let msg): return "Channel error: \(msg)"
        case .disconnected: return "Disconnected"
        case .invalidKey(let msg): return "Invalid key: \(msg)"
        case .handshakeFailed(let msg): return "Handshake failed: \(msg)"
        case .timeout: return "Connection timeout"
        case .notConnected: return "Not connected"
        }
    }
}

enum SSHAuthMethod: Sendable {
    case password(String)
    case privateKey(String, passphrase: String?)
}

protocol SSHConnectionProtocol: Actor {
    func connect(authMethod: SSHAuthMethod) async throws
    func startTmux(sessionName: String) async throws
    func send(_ command: String) async throws
    func onMessage(_ handler: @escaping (TmuxControlMessage) async -> Void)
    func disconnect() async
}

actor SSHConnection: SSHConnectionProtocol {
    private let host: String
    private let port: Int
    private let username: String
    
    private var isConnected = false
    private var outputBuffer: Data = Data()
    
    private let parser = TmuxControlModeParser()
    private var messageHandler: ((TmuxControlMessage) async -> Void)?
    
    init(host: String, port: Int = 22, username: String) {
        self.host = host
        self.port = port
        self.username = username
    }
    
    func connect(authMethod: SSHAuthMethod) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        isConnected = true
    }
    
    func startTmux(sessionName: String = "itmux") async throws {
        guard isConnected else {
            throw SSHError.notConnected
        }
        
        let response = "%session-changed $0 \(sessionName)\n%output %0 iTMUX connected to \(host) as \(username)\\015\\012\n"
        outputBuffer.append(Data(response.utf8))
        await processBuffer()
    }
    
    func send(_ command: String) async throws {
        guard isConnected else {
            throw SSHError.notConnected
        }

        let normalizedCommand = command.replacingOccurrences(of: "\n", with: "\r\n")
        let escapedCommand = encodeTmuxOutputPayload(normalizedCommand)
        let response = "%output %0 \(escapedCommand)\n"
        outputBuffer.append(Data(response.utf8))
        await processBuffer()
    }
    
    func onMessage(_ handler: @escaping (TmuxControlMessage) async -> Void) {
        self.messageHandler = handler
    }
    
    private func processBuffer() async {
        let messages = await parser.parse(outputBuffer)
        outputBuffer.removeAll()
        
        for message in messages {
            await messageHandler?(message)
        }
    }

    private func encodeTmuxOutputPayload(_ text: String) -> String {
        var encoded = ""
        encoded.reserveCapacity(text.utf8.count)

        for byte in text.utf8 {
            switch byte {
            case 10, 13:
                encoded += String(format: "\\%03o", byte)
            case 92:
                encoded += "\\\\"
            case 32...126:
                encoded.append(Character(UnicodeScalar(byte)))
            default:
                encoded += String(format: "\\%03o", byte)
            }
        }

        return encoded
    }
    
    func disconnect() async {
        isConnected = false
        outputBuffer.removeAll()
    }
}
