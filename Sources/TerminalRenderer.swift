import Foundation

/// Handles ANSI escape sequence parsing and terminal state
actor TerminalRenderer {
    private var rows: [[TerminalCell]]
    private var cursorRow: Int = 0
    private var cursorCol: Int = 0
    private var currentStyle = CellStyle()
    
    let columns: Int
    let rowCount: Int
    
    struct TerminalCell {
        var character: Character
        var style: CellStyle
        
        init(character: Character = " ", style: CellStyle = CellStyle()) {
            self.character = character
            self.style = style
        }
    }
    
    struct CellStyle: Equatable {
        var foreground: ANSIColor = .default
        var background: ANSIColor = .default
        var bold: Bool = false
        var dim: Bool = false
        var italic: Bool = false
        var underline: Bool = false
        var reverse: Bool = false
    }
    
    enum ANSIColor: Equatable {
        case `default`
        case black, red, green, yellow, blue, magenta, cyan, white
        case brightBlack, brightRed, brightGreen, brightYellow
        case brightBlue, brightMagenta, brightCyan, brightWhite
        case rgb(r: UInt8, g: UInt8, b: UInt8)
        case indexed(UInt8)
    }
    
    init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rowCount = rows
        self.rows = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
    }
    
    /// Process incoming data and update terminal state
    func process(_ data: Data) -> TerminalUpdate {
        guard let text = String(data: data, encoding: .utf8) else {
            return TerminalUpdate(changedRows: [])
        }
        
        var changedRows = Set<Int>()
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            if char == "\u{1B}" { // ESC
                // Parse ANSI escape sequence
                if let (sequenceEnd, update) = parseEscapeSequence(text, from: i) {
                    i = sequenceEnd
                    if let row = update {
                        changedRows.insert(row)
                    }
                    continue
                }
            }
            
            switch char {
            case "\r":
                cursorCol = 0
                
            case "\n":
                cursorRow += 1
                if cursorRow >= rowCount {
                    scrollUp()
                    cursorRow = rowCount - 1
                    changedRows.formUnion(0..<rowCount)
                }
                
            case "\u{08}": // Backspace
                if cursorCol > 0 {
                    cursorCol -= 1
                }
                
            case "\t":
                // Tab to next 8-column boundary
                cursorCol = ((cursorCol / 8) + 1) * 8
                if cursorCol >= columns {
                    cursorCol = columns - 1
                }
                
            default:
                if char.isASCII && !char.isWhitespace || !char.isASCII {
                    writeChar(char)
                    changedRows.insert(cursorRow)
                }
            }
            
            i = text.index(after: i)
        }
        
        return TerminalUpdate(changedRows: Array(changedRows).sorted())
    }
    
    private func writeChar(_ char: Character) {
        guard cursorRow < rowCount else { return }
        
        if cursorCol >= columns {
            cursorCol = 0
            cursorRow += 1
            if cursorRow >= rowCount {
                scrollUp()
                cursorRow = rowCount - 1
            }
        }
        
        rows[cursorRow][cursorCol] = TerminalCell(character: char, style: currentStyle)
        cursorCol += 1
    }
    
    private func scrollUp() {
        rows.removeFirst()
        rows.append(Array(repeating: TerminalCell(), count: columns))
    }
    
    private func parseEscapeSequence(_ text: String, from start: String.Index) -> (String.Index, Int?)? {
        var i = text.index(after: start)
        guard i < text.endIndex else { return nil }
        
        let nextChar = text[i]
        
        if nextChar == "[" {
            // CSI sequence
            return parseCSI(text, from: i)
        }
        
        // Unknown sequence, skip it
        return (text.index(after: i), nil)
    }
    
    private func parseCSI(_ text: String, from start: String.Index) -> (String.Index, Int?)? {
        var i = text.index(after: start)
        var params: [Int] = []
        var currentParam = ""
        var changedRow: Int?
        
        while i < text.endIndex {
            let char = text[i]
            
            if char.isNumber {
                currentParam.append(char)
            } else if char == ";" {
                params.append(Int(currentParam) ?? 0)
                currentParam = ""
            } else {
                // Command character
                if !currentParam.isEmpty {
                    params.append(Int(currentParam) ?? 0)
                }
                
                changedRow = handleCSICommand(char, params: params)
                return (text.index(after: i), changedRow)
            }
            
            i = text.index(after: i)
        }
        
        return nil
    }
    
    private func handleCSICommand(_ command: Character, params: [Int]) -> Int? {
        switch command {
        case "m": // SGR - Set Graphics Rendition
            handleSGR(params: params)
            return nil
            
        case "H", "f": // CUP - Cursor Position
            let row = (params.first ?? 1) - 1
            let col = (params.count > 1 ? params[1] : 1) - 1
            cursorRow = min(max(row, 0), rowCount - 1)
            cursorCol = min(max(col, 0), columns - 1)
            return nil
            
        case "A": // CUU - Cursor Up
            let n = params.first ?? 1
            cursorRow = max(cursorRow - n, 0)
            return nil
            
        case "B": // CUD - Cursor Down
            let n = params.first ?? 1
            cursorRow = min(cursorRow + n, rowCount - 1)
            return nil
            
        case "C": // CUF - Cursor Forward
            let n = params.first ?? 1
            cursorCol = min(cursorCol + n, columns - 1)
            return nil
            
        case "D": // CUB - Cursor Back
            let n = params.first ?? 1
            cursorCol = max(cursorCol - n, 0)
            return nil
            
        case "J": // ED - Erase in Display
            let mode = params.first ?? 0
            return handleEraseDisplay(mode: mode)
            
        case "K": // EL - Erase in Line
            let mode = params.first ?? 0
            return handleEraseLine(mode: mode)
            
        default:
            return nil
        }
    }
    
    private func handleSGR(params: [Int]) {
        guard !params.isEmpty else {
            currentStyle = CellStyle()
            return
        }
        
        var i = 0
        while i < params.count {
            let param = params[i]
            
            switch param {
            case 0: currentStyle = CellStyle()
            case 1: currentStyle.bold = true
            case 2: currentStyle.dim = true
            case 3: currentStyle.italic = true
            case 4: currentStyle.underline = true
            case 7: currentStyle.reverse = true
            case 22: currentStyle.bold = false; currentStyle.dim = false
            case 23: currentStyle.italic = false
            case 24: currentStyle.underline = false
            case 27: currentStyle.reverse = false
                
            case 30...37: currentStyle.foreground = basicColor(param - 30)
            case 40...47: currentStyle.background = basicColor(param - 40)
            case 90...97: currentStyle.foreground = brightColor(param - 90)
            case 100...107: currentStyle.background = brightColor(param - 100)
                
            case 38, 48: // 256-color or RGB
                if i + 2 < params.count && params[i + 1] == 5 {
                    // 256-color
                    let color = ANSIColor.indexed(UInt8(params[i + 2]))
                    if param == 38 {
                        currentStyle.foreground = color
                    } else {
                        currentStyle.background = color
                    }
                    i += 2
                } else if i + 4 < params.count && params[i + 1] == 2 {
                    // RGB
                    let color = ANSIColor.rgb(
                        r: UInt8(params[i + 2]),
                        g: UInt8(params[i + 3]),
                        b: UInt8(params[i + 4])
                    )
                    if param == 38 {
                        currentStyle.foreground = color
                    } else {
                        currentStyle.background = color
                    }
                    i += 4
                }
                
            case 39: currentStyle.foreground = .default
            case 49: currentStyle.background = .default
                
            default: break
            }
            
            i += 1
        }
    }
    
    private func basicColor(_ index: Int) -> ANSIColor {
        switch index {
        case 0: return .black
        case 1: return .red
        case 2: return .green
        case 3: return .yellow
        case 4: return .blue
        case 5: return .magenta
        case 6: return .cyan
        case 7: return .white
        default: return .default
        }
    }
    
    private func brightColor(_ index: Int) -> ANSIColor {
        switch index {
        case 0: return .brightBlack
        case 1: return .brightRed
        case 2: return .brightGreen
        case 3: return .brightYellow
        case 4: return .brightBlue
        case 5: return .brightMagenta
        case 6: return .brightCyan
        case 7: return .brightWhite
        default: return .default
        }
    }
    
    private func handleEraseDisplay(mode: Int) -> Int? {
        switch mode {
        case 0: // Clear from cursor to end of screen
            for col in cursorCol..<columns {
                rows[cursorRow][col] = TerminalCell()
            }
            for row in (cursorRow + 1)..<rowCount {
                for col in 0..<columns {
                    rows[row][col] = TerminalCell()
                }
            }
            return cursorRow
            
        case 1: // Clear from cursor to beginning of screen
            for col in 0...cursorCol {
                rows[cursorRow][col] = TerminalCell()
            }
            for row in 0..<cursorRow {
                for col in 0..<columns {
                    rows[row][col] = TerminalCell()
                }
            }
            return 0
            
        case 2, 3: // Clear entire screen
            for row in 0..<rowCount {
                for col in 0..<columns {
                    rows[row][col] = TerminalCell()
                }
            }
            return 0
            
        default:
            return nil
        }
    }
    
    private func handleEraseLine(mode: Int) -> Int? {
        switch mode {
        case 0: // Clear from cursor to end of line
            for col in cursorCol..<columns {
                rows[cursorRow][col] = TerminalCell()
            }
            
        case 1: // Clear from cursor to beginning of line
            for col in 0...cursorCol {
                rows[cursorRow][col] = TerminalCell()
            }
            
        case 2: // Clear entire line
            for col in 0..<columns {
                rows[cursorRow][col] = TerminalCell()
            }
            
        default:
            return nil
        }
        
        return cursorRow
    }
    
    func getRow(_ index: Int) -> [TerminalCell]? {
        guard index >= 0 && index < rowCount else { return nil }
        return rows[index]
    }
    
    func getAllRows() -> [[TerminalCell]] {
        rows
    }
    
    func getCursor() -> (row: Int, col: Int) {
        (cursorRow, cursorCol)
    }
}

struct TerminalUpdate {
    let changedRows: [Int]
}
