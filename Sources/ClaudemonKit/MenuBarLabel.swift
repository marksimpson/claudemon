import AppKit

public enum DotStrip {
    public static let dotSize: CGFloat = 8
    public static let tabSpacing: CGFloat = 3
    public static let windowSpacing: CGFloat = 10
    public static let height: CGFloat = 16

    /// X offsets for each dot, widening the gap when the window index changes.
    public static func dotPositions(
        windowIndices: [Int],
        dotSize: CGFloat = DotStrip.dotSize,
        tabSpacing: CGFloat = DotStrip.tabSpacing,
        windowSpacing: CGFloat = DotStrip.windowSpacing
    ) -> [CGFloat] {
        var positions: [CGFloat] = []
        var x: CGFloat = 0
        for (i, windowIndex) in windowIndices.enumerated() {
            if i > 0 {
                let gap = (windowIndex == windowIndices[i - 1]) ? tabSpacing : windowSpacing
                x += dotSize + gap
            }
            positions.append(x)
        }
        return positions
    }

    public static func renderDots(sessions: [Session]) -> NSImage {
        if sessions.isEmpty {
            return renderDot(color: .gray)
        }

        let positions = dotPositions(windowIndices: sessions.map(\.windowIndex))
        let totalWidth = (positions.last ?? 0) + dotSize

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            let y = (height - dotSize) / 2
            for (index, session) in sessions.enumerated() {
                let dotRect = NSRect(x: positions[index], y: y, width: dotSize, height: dotSize)
                session.status.nsColor.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func renderDot(color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: dotSize, height: height), flipped: false) { _ in
            let y = (height - dotSize) / 2
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 0, y: y, width: dotSize, height: dotSize)).fill()
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
