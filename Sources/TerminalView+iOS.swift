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
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.backgroundColor = UIColor(colorScheme.backgroundColor)
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
        // Handle text selection, copy, etc.
    }
}

class TerminalTextView: UITextView {
    private var cursorLayer: CALayer?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupCursorLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCursorLayer()
    }
    
    private func setupCursorLayer() {
        cursorLayer = CALayer()
        cursorLayer?.backgroundColor = UIColor.systemBlue.cgColor
        cursorLayer?.opacity = 0.7
        layer.addSublayer(cursorLayer!)
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
        
        attributedText = attributedString
        updateCursor(row: cursor.row, col: cursor.col)
    }
    
    private func styledString(_ text: String, style: TerminalRenderer.CellStyle, colorScheme: HostColorScheme) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(
                ofSize: 12,
                weight: style.bold ? .bold : .regular
            )
        ]
        
        attributes[.foregroundColor] = uiColor(style.foreground, isBackground: false, colorScheme: colorScheme)
        attributes[.backgroundColor] = uiColor(style.background, isBackground: true, colorScheme: colorScheme)
        
        if style.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    private func uiColor(_ color: TerminalRenderer.ANSIColor, isBackground: Bool, colorScheme: HostColorScheme) -> UIColor {
        switch color {
        case .default:
            return isBackground ? UIColor(colorScheme.backgroundColor) : .label
        case .black: return .black
        case .red: return .systemRed
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .blue: return .systemBlue
        case .magenta: return .systemPurple
        case .cyan: return .systemTeal
        case .white: return .white
        case .brightBlack: return UIColor(white: 0.3, alpha: 1)
        case .brightRed: return UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        case .brightGreen: return UIColor(red: 0.3, green: 1, blue: 0.3, alpha: 1)
        case .brightYellow: return UIColor(red: 1, green: 1, blue: 0.3, alpha: 1)
        case .brightBlue: return UIColor(red: 0.3, green: 0.3, blue: 1, alpha: 1)
        case .brightMagenta: return UIColor(red: 1, green: 0.3, blue: 1, alpha: 1)
        case .brightCyan: return UIColor(red: 0.3, green: 1, blue: 1, alpha: 1)
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
            return .label
        } else if index < 232 {
            let i = Int(index) - 16
            let r = (i / 36) * 51
            let g = ((i % 36) / 6) * 51
            let b = (i % 6) * 51
            return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
        } else {
            let gray = 8 + (Int(index) - 232) * 10
            return UIColor(white: CGFloat(gray)/255, alpha: 1)
        }
    }
    
    private func updateCursor(row: Int, col: Int) {
        guard let font = font else { return }
        
        let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        let lineHeight = font.lineHeight
        
        let x = CGFloat(col) * charWidth + textContainerInset.left
        let y = CGFloat(row) * lineHeight + textContainerInset.top
        
        cursorLayer?.frame = CGRect(x: x, y: y, width: charWidth, height: lineHeight)
    }
}
#endif
