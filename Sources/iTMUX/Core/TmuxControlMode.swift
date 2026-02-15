import Foundation

enum TmuxControlMessage: Sendable {
    case output(paneId: String, data: Data)
    case layoutChange(windowId: String, layout: String)
    case windowAdd(windowId: String, windowName: String?)
    case windowClose(windowId: String)
    case windowRenamed(windowId: String, name: String)
    case sessionChanged(sessionId: String, sessionName: String)
    case sessionClosed(sessionId: String)
    case paneMode(paneId: String, mode: String)
    case paneFocusIn(paneId: String)
    case paneFocusOut(paneId: String)
    case paneSetClipboard(paneId: String, buffer: Data?)
    case exit(reason: String)
    case features(String)
    case subscriptions(String)
    case unknown(String)
    
    var description: String {
        switch self {
        case .output(let paneId, _): return "output(pane: \(paneId))"
        case .layoutChange(let windowId, _): return "layoutChange(window: \(windowId))"
        case .windowAdd(let windowId, _): return "windowAdd(\(windowId))"
        case .windowClose(let windowId): return "windowClose(\(windowId))"
        case .windowRenamed(let windowId, let name): return "windowRenamed(\(windowId), \(name))"
        case .sessionChanged(let sessionId, let name): return "sessionChanged(\(sessionId), \(name))"
        case .sessionClosed(let sessionId): return "sessionClosed(\(sessionId))"
        case .paneMode(let paneId, let mode): return "paneMode(\(paneId), \(mode))"
        case .paneFocusIn(let paneId): return "paneFocusIn(\(paneId))"
        case .paneFocusOut(let paneId): return "paneFocusOut(\(paneId))"
        case .paneSetClipboard(let paneId, _): return "paneSetClipboard(\(paneId))"
        case .exit(let reason): return "exit(\(reason))"
        case .features(let f): return "features(\(f))"
        case .subscriptions(let s): return "subscriptions(\(s))"
        case .unknown(let line): return "unknown(\(line))"
        }
    }
}

enum TmuxCommand {
    case listSessions
    case listWindows(sessionId: String)
    case listPanes(windowId: String)
    case newSession(name: String)
    case newWindow(name: String?)
    case selectWindow(windowId: String)
    case killWindow(windowId: String)
    case splitWindow(windowId: String, horizontal: Bool, percentage: Int?)
    case selectPane(paneId: String)
    case killPane(paneId: String)
    case sendKeys(paneId: String, keys: String, literal: Bool)
    case resizePane(paneId: String, direction: PaneDirection, amount: Int)
    case setWindowSize(windowId: String, width: Int, height: Int)
    case setPaneSize(paneId: String, width: Int, height: Int)
    case renameWindow(windowId: String, name: String)
    case renameSession(sessionId: String, name: String)
    case switchClient(sessionId: String)
    case detachClient
    case setOption(option: String, value: String, global: Bool)
    case refreshClient
    
    enum PaneDirection: String {
        case up = "U"
        case down = "D"
        case left = "L"
        case right = "R"
    }
    
    var commandString: String {
        switch self {
        case .listSessions:
            return "list-sessions"
        case .listWindows(let sessionId):
            return "list-windows -t \(sessionId)"
        case .listPanes(let windowId):
            return "list-panes -t \(windowId)"
        case .newSession(let name):
            return "new-session -d -s \(name)"
        case .newWindow(let name):
            if let name = name {
                return "new-window -n \(name)"
            }
            return "new-window"
        case .selectWindow(let windowId):
            return "select-window -t \(windowId)"
        case .killWindow(let windowId):
            return "kill-window -t \(windowId)"
        case .splitWindow(let windowId, let horizontal, let percentage):
            var cmd = "split-window -t \(windowId)"
            if horizontal {
                cmd += " -h"
            }
            if let pct = percentage {
                cmd += " -p \(pct)"
            }
            return cmd
        case .selectPane(let paneId):
            return "select-pane -t \(paneId)"
        case .killPane(let paneId):
            return "kill-pane -t \(paneId)"
        case .sendKeys(let paneId, let keys, let literal):
            let escaped = keys.replacingOccurrences(of: "'", with: "'\\''")
            if literal {
                return "send-keys -t \(paneId) -l '\(escaped)'"
            }
            return "send-keys -t \(paneId) '\(escaped)'"
        case .resizePane(let paneId, let direction, let amount):
            return "resize-pane -t \(paneId) -\(direction.rawValue) \(amount)"
        case .setWindowSize(let windowId, let width, let height):
            return "set-option -t \(windowId) window-size manual \\; resize-window -t \(windowId) -x \(width) -y \(height)"
        case .setPaneSize(let paneId, let width, let height):
            return "resize-pane -t \(paneId) -x \(width) -y \(height)"
        case .renameWindow(let windowId, let name):
            return "rename-window -t \(windowId) \(name)"
        case .renameSession(let sessionId, let name):
            return "rename-session -t \(sessionId) \(name)"
        case .switchClient(let sessionId):
            return "switch-client -t \(sessionId)"
        case .detachClient:
            return "detach-client"
        case .setOption(let option, let value, let global):
            let flag = global ? "-g" : ""
            return "set-option \(flag) \(option) \(value)"
        case .refreshClient:
            return "refresh-client"
        }
    }
}

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
            
            if let message = parseControlLine(line.trimmingCharacters(in: .whitespaces)) {
                messages.append(message)
            }
        }
        
        return messages
    }
    
    private func parseControlLine(_ line: String) -> TmuxControlMessage? {
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
            return parseOutput(args: args)
        case "layout-change":
            return parseLayoutChange(args: args)
        case "window-add":
            return .windowAdd(windowId: args, windowName: nil)
        case "window-close":
            return .windowClose(windowId: args)
        case "window-renamed":
            let windowParts = args.split(separator: " ", maxSplits: 1)
            let windowId = String(windowParts.first ?? "")
            let name = windowParts.count > 1 ? String(windowParts[1]) : ""
            return .windowRenamed(windowId: windowId, name: name)
        case "session-changed":
            return parseSessionChanged(args: args)
        case "session-closed":
            return .sessionClosed(sessionId: args)
        case "pane-mode":
            let paneParts = args.split(separator: " ", maxSplits: 1)
            let paneId = String(paneParts.first ?? "")
            let mode = paneParts.count > 1 ? String(paneParts[1]) : ""
            return .paneMode(paneId: paneId, mode: mode)
        case "pane-focus-in":
            return .paneFocusIn(paneId: args)
        case "pane-focus-out":
            return .paneFocusOut(paneId: args)
        case "pane-set-clipboard":
            return parsePaneSetClipboard(args: args)
        case "exit":
            return .exit(reason: args)
        case "features":
            return .features(args)
        case "subscriptions":
            return .subscriptions(args)
        default:
            return .unknown(line)
        }
    }
    
    private func parseOutput(args: String) -> TmuxControlMessage {
        let outputParts = args.split(separator: " ", maxSplits: 1)
        guard outputParts.count == 2,
              let paneId = outputParts.first.map(String.init),
              let encodedData = outputParts.last.map(String.init),
              let decodedData = Data(base64Encoded: encodedData.trimmingCharacters(in: .whitespaces)) else {
            return .unknown("output \(args)")
        }
        return .output(paneId: paneId, data: decodedData)
    }
    
    private func parseLayoutChange(args: String) -> TmuxControlMessage {
        let layoutParts = args.split(separator: " ", maxSplits: 1)
        guard layoutParts.count >= 1 else {
            return .unknown("layout-change \(args)")
        }
        let windowId = String(layoutParts[0])
        let layout = layoutParts.count > 1 ? String(layoutParts[1]) : ""
        return .layoutChange(windowId: windowId, layout: layout)
    }
    
    private func parseSessionChanged(args: String) -> TmuxControlMessage {
        let sessionParts = args.split(separator: " ", maxSplits: 1)
        guard sessionParts.count == 2 else {
            return .unknown("session-changed \(args)")
        }
        return .sessionChanged(
            sessionId: String(sessionParts[0]),
            sessionName: String(sessionParts[1])
        )
    }
    
    private func parsePaneSetClipboard(args: String) -> TmuxControlMessage {
        let parts = args.split(separator: " ", maxSplits: 1)
        guard let paneId = parts.first.map(String.init) else {
            return .unknown("pane-set-clipboard \(args)")
        }
        let buffer: Data? = parts.count > 1 ? Data(base64Encoded: String(parts[1])) : nil
        return .paneSetClipboard(paneId: paneId, buffer: buffer)
    }
    
    func reset() {
        buffer.removeAll()
    }
}

struct TmuxLayoutParser {
    struct PaneLayout {
        let paneId: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }
    
    static func parseLayout(_ layout: String) -> [PaneLayout] {
        var panes: [PaneLayout] = []
        
        let checksumPart = layout.split(separator: ",")
        guard checksumPart.count >= 5 else { return panes }
        
        let layoutString = checksumPart[4]
        parseLayoutRecursive(layoutString, into: &panes)
        
        return panes
    }
    
    private static func parseLayoutRecursive(_ layout: Substring, into panes: inout [PaneLayout], offsetX: Int = 0, offsetY: Int = 0) {
        guard !layout.isEmpty else { return }
        
        let firstChar = layout.first!
        
        if firstChar == "{" || firstChar == "[" {
            let isHorizontal = firstChar == "{"
            let innerLayout = layout.dropFirst().dropLast()
            
            var currentX = offsetX
            var currentY = offsetY
            
            var depth = 0
            var start = innerLayout.startIndex
            
            for index in innerLayout.indices {
                let char = innerLayout[index]
                if char == "{" || char == "[" {
                    depth += 1
                } else if char == "}" || char == "]" {
                    depth -= 1
                } else if char == "," && depth == 0 {
                    let part = innerLayout[start..<index]
                    parseLayoutRecursive(part, into: &panes, offsetX: currentX, offsetY: currentY)
                    
                    if isHorizontal {
                        currentX += estimateWidth(part)
                    } else {
                        currentY += estimateHeight(part)
                    }
                    
                    start = innerLayout.index(after: index)
                }
            }
            
            if start < innerLayout.endIndex {
                let part = innerLayout[start..<innerLayout.endIndex]
                parseLayoutRecursive(part, into: &panes, offsetX: currentX, offsetY: currentY)
            }
        } else {
            let parts = layout.split(separator: "x")
            guard parts.count >= 3 else { return }
            
            let width = Int(parts[0]) ?? 0
            let heightParts = parts[1].split(separator: ",")
            let height = Int(heightParts.first ?? "0") ?? 0
            let y = heightParts.count > 1 ? (Int(heightParts[1]) ?? 0) : 0
            let xParts = parts[2].split(separator: ",")
            let x = Int(xParts.first ?? "0") ?? 0
            let paneId = xParts.count > 1 ? String(xParts[1]) : ""
            
            if !paneId.isEmpty {
                panes.append(PaneLayout(paneId: paneId, x: offsetX + x, y: offsetY + y, width: width, height: height))
            }
        }
    }
    
    private static func estimateWidth(_ layout: Substring) -> Int {
        let parts = layout.split(separator: "x")
        return Int(parts.first ?? "0") ?? 0
    }
    
    private static func estimateHeight(_ layout: Substring) -> Int {
        let parts = layout.split(separator: "x")
        guard parts.count > 1 else { return 0 }
        let heightParts = parts[1].split(separator: ",")
        return Int(heightParts.first ?? "0") ?? 0
    }
}
