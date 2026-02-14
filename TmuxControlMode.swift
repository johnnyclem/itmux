import Foundation

/// Represents a tmux control mode message
enum TmuxControlMessage {
    case output(paneId: String, data: Data)
    case layoutChange(sessionId: String, layout: String)
    case windowAdd(windowId: String)
    case windowClose(windowId: String)
    case sessionChanged(sessionId: String, sessionName: String)
    case exit(reason: String)
    case unknown(String)
}

/// Parses tmux control mode (-CC) output
actor TmuxControlModeParser {
    private var buffer = Data()
    
    func parse(_ data: Data) -> [TmuxControlMessage] {
        buffer.append(data)
        
        var messages: [TmuxControlMessage] = []
        
        while let lineRange = buffer.range(of: Data("\n".utf8)) {
            let lineData = buffer.subdata(in: buffer.startIndex..<lineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<lineRange.upperBound)
            
            guard let line = String(data: lineData, encoding: .utf8) else {
                continue
            }
            
            if let message = parseControlLine(line) {
                messages.append(message)
            }
        }
        
        return messages
    }
    
    private func parseControlLine(_ line: String) -> TmuxControlMessage? {
        // Control mode format: %command args...
        guard line.hasPrefix("%") else {
            return nil
        }
        
        let content = String(line.dropFirst())
        let parts = content.split(separator: " ", maxSplits: 1)
        
        guard let command = parts.first else {
            return .unknown(line)
        }
        
        let args = parts.count > 1 ? String(parts[1]) : ""
        
        switch command {
        case "output":
            // %output %0 base64-encoded-data
            let outputParts = args.split(separator: " ", maxSplits: 1)
            guard outputParts.count == 2,
                  let paneId = outputParts.first.map(String.init),
                  let encodedData = outputParts.last.map(String.init),
                  let decodedData = Data(base64Encoded: encodedData) else {
                return .unknown(line)
            }
            return .output(paneId: paneId, data: decodedData)
            
        case "layout-change":
            // %layout-change window-id layout
            let layoutParts = args.split(separator: " ", maxSplits: 1)
            guard layoutParts.count == 2 else {
                return .unknown(line)
            }
            return .layoutChange(
                sessionId: String(layoutParts[0]),
                layout: String(layoutParts[1])
            )
            
        case "window-add":
            return .windowAdd(windowId: args)
            
        case "window-close":
            return .windowClose(windowId: args)
            
        case "session-changed":
            // %session-changed $session_id $session_name
            let sessionParts = args.split(separator: " ", maxSplits: 1)
            guard sessionParts.count == 2 else {
                return .unknown(line)
            }
            return .sessionChanged(
                sessionId: String(sessionParts[0]),
                sessionName: String(sessionParts[1])
            )
            
        case "exit":
            return .exit(reason: args)
            
        default:
            return .unknown(line)
        }
    }
}
