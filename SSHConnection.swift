import Foundation
import SwiftSSH

enum SSHError: Error {
    case connectionFailed(String)
    case authenticationFailed
    case commandFailed(String)
    case disconnected
}

actor SSHConnection {
    private let host: String
    private let port: Int
    private let username: String
    private var session: SSH2.Session?
    private var channel: SSH2.Channel?
    
    private let parser = TmuxControlModeParser()
    private var messageHandler: ((TmuxControlMessage) async -> Void)?
    
    init(host: String, port: Int = 22, username: String) {
        self.host = host
        self.port = port
        self.username = username
    }
    
    func connect(password: String) async throws {
        do {
            session = try SSH2.Session(host: host, port: Int32(port))
            try session?.authenticate(username: username, password: password)
        } catch {
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }
    
    func connect(privateKey: String, passphrase: String? = nil) async throws {
        do {
            session = try SSH2.Session(host: host, port: Int32(port))
            try session?.authenticate(
                username: username,
                privateKey: privateKey,
                passphrase: passphrase ?? ""
            )
        } catch {
            throw SSHError.authenticationFailed
        }
    }
    
    func startTmux(sessionName: String = "mobile") async throws {
        guard let session = session else {
            throw SSHError.connectionFailed("Not connected")
        }
        
        do {
            // Start tmux in control mode
            let command = "tmux -CC new-session -A -s \(sessionName)"
            channel = try session.openChannel()
            try channel?.execute(command)
            
            // Start reading output
            Task {
                await readLoop()
            }
        } catch {
            throw SSHError.commandFailed(error.localizedDescription)
        }
    }
    
    func send(_ command: String) async throws {
        guard let channel = channel else {
            throw SSHError.disconnected
        }
        
        let commandData = (command + "\n").data(using: .utf8)!
        try channel.write(commandData)
    }
    
    func onMessage(_ handler: @escaping (TmuxControlMessage) async -> Void) {
        self.messageHandler = handler
    }
    
    private func readLoop() async {
        guard let channel = channel else { return }
        
        while true {
            do {
                let data = try channel.read()
                if data.isEmpty {
                    // Channel closed
                    break
                }
                
                let messages = await parser.parse(data)
                
                for message in messages {
                    if let handler = messageHandler {
                        await handler(message)
                    }
                }
            } catch {
                print("Read error: \(error)")
                break
            }
        }
    }
    
    func disconnect() async {
        try? channel?.close()
        try? session?.disconnect()
        channel = nil
        session = nil
    }
}
