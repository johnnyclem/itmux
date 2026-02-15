import SwiftUI

#if os(iOS)
import UIKit

struct TerminalView: UIViewRepresentable {
    let paneId: String
    let colorScheme: HostColorScheme
    let renderer: TerminalRenderer
    
    func makeUIView(context: Context) -> TerminalTextView {
        let textView = TerminalTextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.tintColor = UIColor(colorScheme.statusBarColor)
        
        let menuItems: [UIMenuItem] = [
            UIMenuItem(title: "Copy", action: #selector(TerminalTextView.copySelection)),
            UIMenuItem(title: "Select All", action: #selector(TerminalTextView.selectAllTapped))
        ]
        UIMenuController.shared.menuItems = menuItems
        
        return textView
    }
    
    func updateUIView(_ textView: TerminalTextView, context: Context) {
        Task {
            let rows = await renderer.getAllRows()
            let cursor = await renderer.getCursor()
            
            await MainActor.run {
                textView.updateContent(rows: rows, cursor: cursor, colorScheme: colorScheme)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            var actions: [UIMenuElement] = []
            
            let copyAction = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = textView.text(in: range)
            }
            actions.append(copyAction)
            
            let selectAllAction = UIAction(title: "Select All", image: UIImage(systemName: "text.alignleft")) { _ in
                textView.selectAll(nil)
            }
            actions.append(selectAllAction)
            
            return UIMenu(children: actions)
        }
    }
}

class TerminalTextView: UITextView {
    private var cursorLayer: CALayer?
    private var cursorBlinkTimer: Timer?
    private var lastContent: String = ""
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupCursorLayer()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCursorLayer()
        setupGestures()
    }
    
    private func setupCursorLayer() {
        cursorLayer = CALayer()
        cursorLayer?.backgroundColor = UIColor.systemCyan.cgColor
        cursorLayer?.opacity = 0.8
        layer.addSublayer(cursorLayer!)
        
        startCursorBlink()
    }
    
    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        addGestureRecognizer(longPress)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let position = closestPosition(to: point)
        if let position = position {
            let tapRange = tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: UITextDirection(rawValue: UITextStorageDirection.backward.rawValue))
            if let range = tapRange {
                selectedTextRange = range
            }
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            becomeFirstResponder()
            let menu = UIMenuController.shared
            menu.showMenu(from: self, rect: bounds)
        }
    }
    
    @objc func copySelection() {
        if let selectedText = selectedText {
            UIPasteboard.general.string = selectedText
        }
    }
    
    @objc func selectAllTapped() {
        selectAll(nil)
    }
    
    override func copy(_ sender: Any?) {
        if let selectedText = selectedText {
            UIPasteboard.general.string = selectedText
        }
    }
    
    private func startCursorBlink() {
        cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let cursor = self.cursorLayer else { return }
            cursor.opacity = cursor.opacity > 0 ? 0 : 0.8
        }
    }
    
    func updateContent(rows: [[TerminalRenderer.TerminalCell]], cursor: (row: Int, col: Int), colorScheme: HostColorScheme) {
        let attributedString = NSMutableAttributedString()
        
        for (rowIndex, row) in rows.enumerated() {
            var currentRun = ""
            var currentStyle: TerminalRenderer.CellStyle?
            
            for cell in row {
                if currentStyle == cell.style {
                    currentRun.append(cell.character)
                } else {
                    if !currentRun.isEmpty, let style = currentStyle {
                        attributedString.append(styledString(currentRun, style: style, colorScheme: colorScheme))
                    }
                    currentRun = String(cell.character)
                    currentStyle = cell.style
                }
            }
            
            if !currentRun.isEmpty, let style = currentStyle {
                attributedString.append(styledString(currentRun, style: style, colorScheme: colorScheme))
            }
            
            if rowIndex < rows.count - 1 {
                attributedString.append(NSAttributedString(string: "\n"))
            }
        }
        
        let newContent = attributedString.string
        if newContent != lastContent {
            attributedText = attributedString
            lastContent = newContent
        }
        
        updateCursor(row: cursor.row, col: cursor.col)
    }
    
    private func styledString(_ text: String, style: TerminalRenderer.CellStyle, colorScheme: HostColorScheme) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(
                ofSize: 12,
                weight: style.bold ? .bold : .regular
            )
        ]
        
        let fgColor = style.reverse ? uiColor(style.background, isBackground: false, colorScheme: colorScheme) : uiColor(style.foreground, isBackground: false, colorScheme: colorScheme)
        let bgColor = style.reverse ? uiColor(style.foreground, isBackground: true, colorScheme: colorScheme) : uiColor(style.background, isBackground: true, colorScheme: colorScheme)
        
        if style.dim {
            attributes[.foregroundColor] = fgColor.withAlphaComponent(0.6)
        } else {
            attributes[.foregroundColor] = fgColor
        }
        
        if bgColor != .clear {
            attributes[.backgroundColor] = bgColor
        }
        
        if style.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        if style.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    private func uiColor(_ color: TerminalRenderer.ANSIColor, isBackground: Bool, colorScheme: HostColorScheme) -> UIColor {
        switch color {
        case .default:
            return isBackground ? .black : .white
        case .black: return UIColor(white: 0, alpha: 1)
        case .red: return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .green: return UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
        case .yellow: return UIColor(red: 0.9, green: 0.8, blue: 0.2, alpha: 1)
        case .blue: return UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1)
        case .magenta: return UIColor(red: 0.8, green: 0.3, blue: 0.8, alpha: 1)
        case .cyan: return UIColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1)
        case .white: return UIColor(white: 0.9, alpha: 1)
        case .brightBlack: return UIColor(white: 0.4, alpha: 1)
        case .brightRed: return UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        case .brightGreen: return UIColor(red: 0.4, green: 1, blue: 0.4, alpha: 1)
        case .brightYellow: return UIColor(red: 1, green: 1, blue: 0.4, alpha: 1)
        case .brightBlue: return UIColor(red: 0.5, green: 0.7, blue: 1, alpha: 1)
        case .brightMagenta: return UIColor(red: 1, green: 0.5, blue: 1, alpha: 1)
        case .brightCyan: return UIColor(red: 0.4, green: 1, blue: 1, alpha: 1)
        case .brightWhite: return .white
        case .rgb(let r, let g, let b):
            return UIColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1
            )
        case .indexed(let index):
            return indexed256Color(index)
        }
    }
    
    private func indexed256Color(_ index: UInt8) -> UIColor {
        if index < 16 {
            let colors: [UIColor] = [
                .black, .red, .green, .yellow, .blue, .magenta, .cyan, .white,
                UIColor(white: 0.4, alpha: 1),
                UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1),
                UIColor(red: 0.4, green: 1, blue: 0.4, alpha: 1),
                UIColor(red: 1, green: 1, blue: 0.4, alpha: 1),
                UIColor(red: 0.5, green: 0.7, blue: 1, alpha: 1),
                UIColor(red: 1, green: 0.5, blue: 1, alpha: 1),
                UIColor(red: 0.4, green: 1, blue: 1, alpha: 1),
                .white
            ]
            return colors[Int(index)]
        } else if index < 232 {
            let i = Int(index) - 16
            let r = (i / 36) % 6
            let g = (i / 6) % 6
            let b = i % 6
            return UIColor(
                red: CGFloat(r * 51) / 255,
                green: CGFloat(g * 51) / 255,
                blue: CGFloat(b * 51) / 255,
                alpha: 1
            )
        } else {
            let gray = 8 + (Int(index) - 232) * 10
            return UIColor(white: CGFloat(gray) / 255, alpha: 1)
        }
    }
    
    private func updateCursor(row: Int, col: Int) {
        guard let font = font else { return }
        
        let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        let lineHeight = font.lineHeight
        
        let x = CGFloat(col) * charWidth + textContainerInset.left
        let y = CGFloat(row) * lineHeight + textContainerInset.top
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cursorLayer?.frame = CGRect(x: x, y: y, width: charWidth, height: lineHeight)
        CATransaction.commit()
    }
    
    deinit {
        cursorBlinkTimer?.invalidate()
    }
}

#else

import AppKit

struct TerminalView: NSViewRepresentable {
    let paneId: String
    let colorScheme: HostColorScheme
    let renderer: TerminalRenderer
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.drawsBackground = true
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        Task {
            let rows = await renderer.getAllRows()
            let cursor = await renderer.getCursor()
            
            await MainActor.run {
                updateContent(textView: textView, rows: rows, colorScheme: colorScheme)
            }
        }
    }
    
    private func updateContent(textView: NSTextView, rows: [[TerminalRenderer.TerminalCell]], colorScheme: HostColorScheme) {
        let attributedString = NSMutableAttributedString()
        
        for (rowIndex, row) in rows.enumerated() {
            var currentRun = ""
            var currentStyle: TerminalRenderer.CellStyle?
            
            for cell in row {
                if currentStyle == cell.style {
                    currentRun.append(cell.character)
                } else {
                    if !currentRun.isEmpty, let style = currentStyle {
                        attributedString.append(styledString(currentRun, style: style, colorScheme: colorScheme))
                    }
                    currentRun = String(cell.character)
                    currentStyle = cell.style
                }
            }
            
            if !currentRun.isEmpty, let style = currentStyle {
                attributedString.append(styledString(currentRun, style: style, colorScheme: colorScheme))
            }
            
            if rowIndex < rows.count - 1 {
                attributedString.append(NSAttributedString(string: "\n"))
            }
        }
        
        textView.textStorage?.setAttributedString(attributedString)
    }
    
    private func styledString(_ text: String, style: TerminalRenderer.CellStyle, colorScheme: HostColorScheme) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(
                ofSize: 12,
                weight: style.bold ? .bold : .regular
            )
        ]
        
        attributes[.foregroundColor] = style.reverse ? nsColor(style.background) : nsColor(style.foreground)
        
        let bgColor = style.reverse ? nsColor(style.foreground) : nsColor(style.background)
        if bgColor != .clear {
            attributes[.backgroundColor] = bgColor
        }
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    private func nsColor(_ color: TerminalRenderer.ANSIColor) -> NSColor {
        switch color {
        case .default: return .white
        case .black: return .black
        case .red: return .red
        case .green: return .green
        case .yellow: return .yellow
        case .blue: return .blue
        case .magenta: return .magenta
        case .cyan: return .cyan
        case .white: return .white
        case .brightBlack: return NSColor.gray
        case .brightRed: return NSColor.red.withAlphaComponent(0.8)
        case .brightGreen: return NSColor.green.withAlphaComponent(0.8)
        case .brightYellow: return NSColor.yellow.withAlphaComponent(0.8)
        case .brightBlue: return NSColor.blue.withAlphaComponent(0.8)
        case .brightMagenta: return NSColor.magenta.withAlphaComponent(0.8)
        case .brightCyan: return NSColor.cyan.withAlphaComponent(0.8)
        case .brightWhite: return .white
        case .rgb(let r, let g, let b):
            return NSColor(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: 1
            )
        case .indexed(let index):
            return indexed256Color(index)
        }
    }
    
    private func indexed256Color(_ index: UInt8) -> NSColor {
        if index < 16 {
            return NSColor.white
        } else if index < 232 {
            let i = Int(index) - 16
            let r = (i / 36) % 6
            let g = (i / 6) % 6
            let b = i % 6
            return NSColor(
                red: CGFloat(r * 51) / 255,
                green: CGFloat(g * 51) / 255,
                blue: CGFloat(b * 51) / 255,
                alpha: 1
            )
        } else {
            let gray = 8 + (Int(index) - 232) * 10
            return NSColor(white: CGFloat(gray) / 255, alpha: 1)
        }
    }
}

#endif
