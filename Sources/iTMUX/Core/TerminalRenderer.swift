import Foundation

struct TerminalUpdate: Sendable {
    let changedRows: [Int]
    let cursorMoved: Bool
    let fullRedraw: Bool
}

actor TerminalRenderer {
    private var primaryBuffer: [[TerminalCell]]
    private var alternateBuffer: [[TerminalCell]]?
    private var usingAlternateBuffer: Bool = false
    
    private var cursorRow: Int = 0
    private var cursorCol: Int = 0
    private var savedCursorRow: Int = 0
    private var savedCursorCol: Int = 0
    private var currentStyle = CellStyle()
    
    private var scrollTop: Int = 0
    private var scrollBottom: Int
    
    var columns: Int
    var rowCount: Int
    
    private var tabStops: Set<Int>
    
    struct TerminalCell: Sendable {
        var character: Character
        var style: CellStyle
        
        init(character: Character = " ", style: CellStyle = CellStyle()) {
            self.character = character
            self.style = style
        }
    }
    
    struct CellStyle: Equatable, Sendable {
        var foreground: ANSIColor = .default
        var background: ANSIColor = .default
        var bold: Bool = false
        var dim: Bool = false
        var italic: Bool = false
        var underline: Bool = false
        var blink: Bool = false
        var reverse: Bool = false
        var hidden: Bool = false
        var strikethrough: Bool = false
    }
    
    enum ANSIColor: Equatable, Sendable {
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
        self.scrollBottom = rows - 1
        self.primaryBuffer = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
        self.tabStops = Set(stride(from: 0, to: columns, by: 8))
    }
    
    private var currentBuffer: [[TerminalCell]] {
        get {
            usingAlternateBuffer ? (alternateBuffer ?? primaryBuffer) : primaryBuffer
        }
        set {
            if usingAlternateBuffer {
                alternateBuffer = newValue
            } else {
                primaryBuffer = newValue
            }
        }
    }
    
    func process(_ data: Data) -> TerminalUpdate {
        guard let text = String(data: data, encoding: .utf8) else {
            return TerminalUpdate(changedRows: [], cursorMoved: false, fullRedraw: false)
        }
        
        var changedRows = Set<Int>()
        var cursorMoved = false
        var fullRedraw = false
        
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = text[i]
            
            if char == "\u{1B}" {
                if let (sequenceEnd, update) = parseEscapeSequence(text, from: i) {
                    i = sequenceEnd
                    if let rows = update.changedRows {
                        changedRows.formUnion(rows.flatMap { $0 })
                    }
                    if update.cursorMoved { cursorMoved = true }
                    if update.fullRedraw { fullRedraw = true }
                    continue
                }
            }
            
            let result = processCharacter(char)
            changedRows.formUnion(result.changedRows)
            if result.cursorMoved { cursorMoved = true }
            
            i = text.index(after: i)
        }
        
        return TerminalUpdate(
            changedRows: Array(changedRows).sorted(),
            cursorMoved: cursorMoved,
            fullRedraw: fullRedraw
        )
    }
    
    private func processCharacter(_ char: Character) -> (changedRows: Set<Int>, cursorMoved: Bool) {
        var changedRows: Set<Int> = []
        var cursorMoved = false
        
        switch char {
        case "\r":
            cursorCol = 0
            cursorMoved = true
            
        case "\n", "\u{0B}", "\u{0C}":
            if cursorRow == scrollBottom {
                scrollUp()
                changedRows.formUnion(0...rowCount - 1)
            } else if cursorRow < rowCount - 1 {
                cursorRow += 1
            }
            cursorMoved = true
            
        case "\u{08}":
            if cursorCol > 0 {
                cursorCol -= 1
                cursorMoved = true
            }
            
        case "\u{07}":
            break
            
        case "\u{09}":
            if let nextTab = tabStops.first(where: { $0 > cursorCol }) {
                cursorCol = min(nextTab, columns - 1)
            } else {
                cursorCol = columns - 1
            }
            cursorMoved = true
            
        case "\u{00}":
            break
            
        default:
            if char.isASCII && char.asciiValue! >= 32 || !char.isASCII {
                writeChar(char)
                changedRows.insert(cursorRow)
            }
        }
        
        return (changedRows, cursorMoved)
    }
    
    private func writeChar(_ char: Character) {
        var buffer = currentBuffer
        guard cursorRow < rowCount else { return }
        
        if cursorCol >= columns {
            cursorCol = 0
            if cursorRow == scrollBottom {
                scrollUp()
            } else if cursorRow < rowCount - 1 {
                cursorRow += 1
            }
        }
        
        buffer[cursorRow][cursorCol] = TerminalCell(character: char, style: currentStyle)
        currentBuffer = buffer
        cursorCol += 1
    }
    
    private func scrollUp() {
        var buffer = currentBuffer
        buffer.remove(at: scrollTop)
        buffer.insert(Array(repeating: TerminalCell(), count: columns), at: scrollBottom)
        currentBuffer = buffer
    }
    
    private func scrollDown() {
        var buffer = currentBuffer
        buffer.remove(at: scrollBottom)
        buffer.insert(Array(repeating: TerminalCell(), count: columns), at: scrollTop)
        currentBuffer = buffer
    }
    
    private func parseEscapeSequence(_ text: String, from start: String.Index) -> (String.Index, ParseResult)? {
        guard start < text.endIndex else { return nil }
        
        let nextIndex = text.index(after: start)
        guard nextIndex < text.endIndex else { return nil }
        
        let nextChar = text[nextIndex]
        
        switch nextChar {
        case "[":
            return parseCSI(text, from: nextIndex)
        case "]":
            return parseOSC(text, from: nextIndex)
        case "7":
            savedCursorRow = cursorRow
            savedCursorCol = cursorCol
            return (text.index(after: nextIndex), ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false))
        case "8":
            cursorRow = savedCursorRow
            cursorCol = savedCursorCol
            return (text.index(after: nextIndex), ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false))
        case "M":
            if cursorRow == scrollTop {
                scrollDown()
            } else if cursorRow > 0 {
                cursorRow -= 1
            }
            return (text.index(after: nextIndex), ParseResult(changedRows: [scrollTop...cursorRow], cursorMoved: true, fullRedraw: false))
        case "D":
            if cursorRow == scrollBottom {
                scrollUp()
            } else if cursorRow < rowCount - 1 {
                cursorRow += 1
            }
            return (text.index(after: nextIndex), ParseResult(changedRows: [cursorRow...scrollBottom], cursorMoved: true, fullRedraw: false))
        case "c":
            reset()
            return (text.index(after: nextIndex), ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: true))
        default:
            return (text.index(after: nextIndex), ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false))
        }
    }
    
    private struct ParseResult {
        let changedRows: [ClosedRange<Int>]?
        let cursorMoved: Bool
        let fullRedraw: Bool
        
        var changedRowsFlat: Set<Int> {
            Set(changedRows?.flatMap { $0 } ?? [])
        }
    }
    
    private func parseCSI(_ text: String, from start: String.Index) -> (String.Index, ParseResult)? {
        var i = text.index(after: start)
        var params: [CSIParam] = []
        var privateModePrefix: Character? = nil
        
        if i < text.endIndex {
            let char = text[i]
            if char == "?" || char == ">" || char == "!" || char == "=" {
                privateModePrefix = char
                i = text.index(after: i)
            }
        }
        
        while i < text.endIndex {
            let char = text[i]
            
            if char.isNumber {
                var numStr = String(char)
                i = text.index(after: i)
                while i < text.endIndex && text[i].isNumber {
                    numStr.append(text[i])
                    i = text.index(after: i)
                }
                params.append(.number(Int(numStr) ?? 0))
            } else if char == ";" {
                params.append(.separator)
                i = text.index(after: i)
            } else if char == ":" {
                params.append(.subSeparator)
                i = text.index(after: i)
            } else if char >= "@" && char <= "~" {
                let result = handleCSICommand(char, params: params, privatePrefix: privateModePrefix)
                return (text.index(after: i), result)
            } else {
                i = text.index(after: i)
            }
        }
        
        return nil
    }
    
    private enum CSIParam: Equatable {
        case number(Int)
        case separator
        case subSeparator
        
        var numberValue: Int? {
            if case .number(let n) = self { return n }
            return nil
        }
    }
    
    private func handleCSICommand(_ command: Character, params: [CSIParam], privatePrefix: Character?) -> ParseResult {
        let numericParams = params.compactMap { $0.numberValue }
        let p = numericParams.first ?? 1
        let q = numericParams.count > 1 ? numericParams[1] : 1
        let r = numericParams.count > 2 ? numericParams[2] : 1
        
        switch command {
        case "m":
            handleSGR(params: numericParams)
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        case "H", "f":
            cursorRow = min(max(p - 1, 0), rowCount - 1)
            cursorCol = min(max(q - 1, 0), columns - 1)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "A":
            cursorRow = max(cursorRow - p, 0)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "B":
            cursorRow = min(cursorRow + p, rowCount - 1)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "C":
            cursorCol = min(cursorCol + p, columns - 1)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "D":
            cursorCol = max(cursorCol - p, 0)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "E":
            cursorRow = min(cursorRow + p, rowCount - 1)
            cursorCol = 0
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "F":
            cursorRow = max(cursorRow - p, 0)
            cursorCol = 0
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "G":
            cursorCol = min(max(p - 1, 0), columns - 1)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "J":
            return handleEraseDisplay(mode: p)
            
        case "K":
            return handleEraseLine(mode: p)
            
        case "L":
            return insertLines(count: p)
            
        case "M":
            return deleteLines(count: p)
            
        case "P":
            return deleteChars(count: p)
            
        case "@":
            return insertChars(count: p)
            
        case "X":
            return eraseChars(count: p)
            
        case "S":
            for _ in 0..<p { scrollUp() }
            return ParseResult(changedRows: [scrollTop...scrollBottom], cursorMoved: false, fullRedraw: false)
            
        case "T":
            for _ in 0..<p { scrollDown() }
            return ParseResult(changedRows: [scrollTop...scrollBottom], cursorMoved: false, fullRedraw: false)
            
        case "d":
            cursorRow = min(max(p - 1, 0), rowCount - 1)
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "r":
            scrollTop = max(0, p - 1)
            scrollBottom = min(rowCount - 1, q - 1)
            cursorRow = 0
            cursorCol = 0
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "s":
            savedCursorRow = cursorRow
            savedCursorCol = cursorCol
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        case "u":
            cursorRow = savedCursorRow
            cursorCol = savedCursorCol
            return ParseResult(changedRows: nil, cursorMoved: true, fullRedraw: false)
            
        case "h":
            if privatePrefix == "?" {
                return handlePrivateModeSet(numericParams)
            }
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        case "l":
            if privatePrefix == "?" {
                return handlePrivateModeReset(numericParams)
            }
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        case "c":
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        case "n":
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
            
        default:
            return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
        }
    }
    
    private func handlePrivateModeSet(_ params: [Int]) -> ParseResult {
        for param in params {
            switch param {
            case 1049:
                if !usingAlternateBuffer {
                    alternateBuffer = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rowCount)
                    usingAlternateBuffer = true
                }
                return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: true)
            case 1:
                break
            default:
                break
            }
        }
        return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
    }
    
    private func handlePrivateModeReset(_ params: [Int]) -> ParseResult {
        for param in params {
            switch param {
            case 1049:
                if usingAlternateBuffer {
                    usingAlternateBuffer = false
                    alternateBuffer = nil
                }
                return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: true)
            case 1:
                break
            default:
                break
            }
        }
        return ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false)
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
            case 5, 6: currentStyle.blink = true
            case 7: currentStyle.reverse = true
            case 8: currentStyle.hidden = true
            case 9: currentStyle.strikethrough = true
            case 22: currentStyle.bold = false; currentStyle.dim = false
            case 23: currentStyle.italic = false
            case 24: currentStyle.underline = false
            case 25: currentStyle.blink = false
            case 27: currentStyle.reverse = false
            case 28: currentStyle.hidden = false
            case 29: currentStyle.strikethrough = false
                
            case 30...37: currentStyle.foreground = basicColor(param - 30)
            case 38:
                if i + 2 < params.count && params[i + 1] == 5 {
                    currentStyle.foreground = ANSIColor.indexed(UInt8(params[i + 2]))
                    i += 2
                } else if i + 4 < params.count && params[i + 1] == 2 {
                    currentStyle.foreground = ANSIColor.rgb(
                        r: UInt8(params[i + 2]),
                        g: UInt8(params[i + 3]),
                        b: UInt8(params[i + 4])
                    )
                    i += 4
                }
            case 39: currentStyle.foreground = .default
                
            case 40...47: currentStyle.background = basicColor(param - 40)
            case 48:
                if i + 2 < params.count && params[i + 1] == 5 {
                    currentStyle.background = ANSIColor.indexed(UInt8(params[i + 2]))
                    i += 2
                } else if i + 4 < params.count && params[i + 1] == 2 {
                    currentStyle.background = ANSIColor.rgb(
                        r: UInt8(params[i + 2]),
                        g: UInt8(params[i + 3]),
                        b: UInt8(params[i + 4])
                    )
                    i += 4
                }
            case 49: currentStyle.background = .default
                
            case 90...97: currentStyle.foreground = brightColor(param - 90)
            case 100...107: currentStyle.background = brightColor(param - 100)
                
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
    
    private func handleEraseDisplay(mode: Int) -> ParseResult {
        var buffer = currentBuffer
        var changedRows: ClosedRange<Int>?
        
        switch mode {
        case 0:
            for col in cursorCol..<columns {
                buffer[cursorRow][col] = TerminalCell()
            }
            for row in (cursorRow + 1)..<rowCount {
                for col in 0..<columns {
                    buffer[row][col] = TerminalCell()
                }
            }
            changedRows = cursorRow...(rowCount - 1)
            
        case 1:
            for col in 0...cursorCol {
                buffer[cursorRow][col] = TerminalCell()
            }
            for row in 0..<cursorRow {
                for col in 0..<columns {
                    buffer[row][col] = TerminalCell()
                }
            }
            changedRows = 0...cursorRow
            
        case 2, 3:
            for row in 0..<rowCount {
                for col in 0..<columns {
                    buffer[row][col] = TerminalCell()
                }
            }
            changedRows = 0...(rowCount - 1)
            
        default:
            break
        }
        
        currentBuffer = buffer
        return ParseResult(changedRows: changedRows.map { [$0] }, cursorMoved: false, fullRedraw: mode >= 2)
    }
    
    private func handleEraseLine(mode: Int) -> ParseResult {
        var buffer = currentBuffer
        
        switch mode {
        case 0:
            for col in cursorCol..<columns {
                buffer[cursorRow][col] = TerminalCell()
            }
        case 1:
            for col in 0...cursorCol {
                buffer[cursorRow][col] = TerminalCell()
            }
        case 2:
            for col in 0..<columns {
                buffer[cursorRow][col] = TerminalCell()
            }
        default:
            break
        }
        
        currentBuffer = buffer
        return ParseResult(changedRows: [cursorRow...cursorRow], cursorMoved: false, fullRedraw: false)
    }
    
    private func insertLines(count: Int) -> ParseResult {
        var buffer = currentBuffer
        
        for _ in 0..<count {
            if cursorRow <= scrollBottom {
                buffer.remove(at: scrollBottom)
                buffer.insert(Array(repeating: TerminalCell(), count: columns), at: cursorRow)
            }
        }
        
        currentBuffer = buffer
        return ParseResult(changedRows: [cursorRow...scrollBottom], cursorMoved: false, fullRedraw: false)
    }
    
    private func deleteLines(count: Int) -> ParseResult {
        var buffer = currentBuffer
        
        for _ in 0..<count {
            if cursorRow <= scrollBottom {
                buffer.remove(at: cursorRow)
                buffer.insert(Array(repeating: TerminalCell(), count: columns), at: scrollBottom)
            }
        }
        
        currentBuffer = buffer
        return ParseResult(changedRows: [cursorRow...scrollBottom], cursorMoved: false, fullRedraw: false)
    }
    
    private func deleteChars(count: Int) -> ParseResult {
        var buffer = currentBuffer
        let row = buffer[cursorRow]
        
        var newRow = row
        for i in cursorCol..<(columns - count) {
            newRow[i] = row[i + count]
        }
        for i in max(cursorCol, columns - count)..<columns {
            newRow[i] = TerminalCell()
        }
        
        buffer[cursorRow] = newRow
        currentBuffer = buffer
        
        return ParseResult(changedRows: [cursorRow...cursorRow], cursorMoved: false, fullRedraw: false)
    }
    
    private func insertChars(count: Int) -> ParseResult {
        var buffer = currentBuffer
        let row = buffer[cursorRow]
        
        var newRow = row
        for i in stride(from: columns - 1, through: cursorCol + count, by: -1) {
            newRow[i] = row[i - count]
        }
        for i in cursorCol..<min(cursorCol + count, columns) {
            newRow[i] = TerminalCell()
        }
        
        buffer[cursorRow] = newRow
        currentBuffer = buffer
        
        return ParseResult(changedRows: [cursorRow...cursorRow], cursorMoved: false, fullRedraw: false)
    }
    
    private func eraseChars(count: Int) -> ParseResult {
        var buffer = currentBuffer
        
        for i in cursorCol..<min(cursorCol + count, columns) {
            buffer[cursorRow][i] = TerminalCell()
        }
        
        currentBuffer = buffer
        return ParseResult(changedRows: [cursorRow...cursorRow], cursorMoved: false, fullRedraw: false)
    }
    
    private func parseOSC(_ text: String, from start: String.Index) -> (String.Index, ParseResult)? {
        var i = text.index(after: start)
        var oscContent = ""
        
        while i < text.endIndex {
            let char = text[i]
            if char == "\u{07}" || (char == "\\" && i > text.index(after: start) && text[text.index(before: i)] == "\u{1B}") {
                if char == "\\" {
                    i = text.index(after: i)
                } else {
                    i = text.index(after: i)
                }
                handleOSC(oscContent)
                return (i, ParseResult(changedRows: nil, cursorMoved: false, fullRedraw: false))
            }
            oscContent.append(char)
            i = text.index(after: i)
        }
        
        return nil
    }
    
    private func handleOSC(_ content: String) {
        let parts = content.split(separator: ";", maxSplits: 1)
        guard let commandStr = parts.first, let command = Int(commandStr) else { return }
        
        switch command {
        case 0, 1, 2:
            break
        case 7:
            break
        default:
            break
        }
    }
    
    private func reset() {
        primaryBuffer = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rowCount)
        alternateBuffer = nil
        usingAlternateBuffer = false
        cursorRow = 0
        cursorCol = 0
        savedCursorRow = 0
        savedCursorCol = 0
        currentStyle = CellStyle()
        scrollTop = 0
        scrollBottom = rowCount - 1
    }
    
    func getRow(_ index: Int) -> [TerminalCell]? {
        guard index >= 0 && index < rowCount else { return nil }
        return currentBuffer[index]
    }
    
    func getAllRows() -> [[TerminalCell]] {
        currentBuffer
    }
    
    func getCursor() -> (row: Int, col: Int) {
        (cursorRow, cursorCol)
    }
    
    func resize(columns: Int, rows: Int) {
        self.columns = columns
        self.rowCount = rows
        self.scrollBottom = rows - 1
        
        var newBuffer = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
        for row in 0..<min(rowCount, rows) {
            for col in 0..<min(self.columns, columns) {
                newBuffer[row][col] = currentBuffer[row][col]
            }
        }
        primaryBuffer = newBuffer
        
        if cursorRow >= rows { cursorRow = rows - 1 }
        if cursorCol >= columns { cursorCol = columns - 1 }
    }
}
