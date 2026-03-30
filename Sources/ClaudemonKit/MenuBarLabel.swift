import AppKit

public enum DotStrip {
    public static func renderDots(sessions: [Session]) -> NSImage {
        let dotSize: CGFloat = 8
        let spacing: CGFloat = 3
        let colors: [NSColor] = sessions.isEmpty
            ? [.gray]
            : sessions.map { $0.status.nsColor }

        let totalWidth = CGFloat(colors.count) * dotSize + CGFloat(max(colors.count - 1, 0)) * spacing
        let height: CGFloat = 16

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { rect in
            for (index, color) in colors.enumerated() {
                let x = CGFloat(index) * (dotSize + spacing)
                let y = (height - dotSize) / 2
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                color.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

extension SessionStatus {
    public var nsColor: NSColor {
        switch self {
        case .permission: return .systemRed
        case .idle: return .systemYellow
        case .working: return .systemGreen
        }
    }
}
