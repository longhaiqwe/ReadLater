import Foundation

private extension CGRect {
    // NSEvent can report the exact top/right edge; CGRect.contains excludes it.
    func containsIncludingBoundary(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

enum ScreenEdge: String, CaseIterable {
    case top, bottom, left, right
    var vertical: Bool { self == .left || self == .right }
    var title: String {
        switch self {
        case .left: return "左侧"
        case .right: return "右侧"
        case .top: return "上方"
        case .bottom: return "下方"
        }
    }
    func frame(screen: CGRect, visible: CGRect, cardSize: CGSize) -> CGRect {
        // Reserve space for the peg, sway, padding and a separate control strip.
        if vertical {
            let width = min(cardSize.width + 72, visible.width)
            return CGRect(x: self == .left ? visible.minX : visible.maxX - width,
                          y: visible.minY, width: width, height: visible.height)
        }
        let height = min(cardSize.height + 102, visible.height)
        return CGRect(x: visible.minX, y: self == .top ? visible.maxY - height : visible.minY,
                      width: visible.width, height: height)
    }
    static func nearest(to point: CGPoint, in frame: CGRect) -> ScreenEdge {
        let distances: [(ScreenEdge, CGFloat)] = [(.left, abs(point.x - frame.minX)), (.right, abs(point.x - frame.maxX)),
                                                 (.top, abs(point.y - frame.maxY)), (.bottom, abs(point.y - frame.minY))]
        return distances.min { $0.1 < $1.1 }!.0
    }
    func containsHoverPoint(_ point: CGPoint, screen: CGRect) -> Bool {
        guard screen.containsIncludingBoundary(point) else { return false }
        let distance: CGFloat
        switch self {
        case .left: distance = point.x - screen.minX
        case .right: distance = screen.maxX - point.x
        case .top: distance = screen.maxY - point.y
        case .bottom: distance = point.y - screen.minY
        }
        return distance <= 8
    }

    func containsPanelPoint(_ point: CGPoint, panel: CGRect, screen: CGRect) -> Bool {
        guard screen.containsIncludingBoundary(point) else { return false }
        var region = panel.insetBy(dx: -12, dy: -12)
        switch self {
        case .top:
            region.size.height = screen.maxY - region.minY
        case .bottom:
            let maxY = region.maxY
            region.origin.y = screen.minY
            region.size.height = maxY - screen.minY
        case .left:
            let maxX = region.maxX
            region.origin.x = screen.minX
            region.size.width = maxX - screen.minX
        case .right:
            region.size.width = screen.maxX - region.minX
        }
        return region.containsIncludingBoundary(point)
    }
}

/// Samples elapsed time, so a stationary pointer can reveal the panel too.
struct EdgeHoverTrigger {
    private var enteredAt: TimeInterval?
    private var triggered = false

    mutating func update(isAtEdge: Bool, now: TimeInterval) -> Bool {
        guard isAtEdge else {
            enteredAt = nil
            triggered = false
            return false
        }
        guard let enteredAt else { self.enteredAt = now; return false }
        guard !triggered, now - enteredAt >= 0.3 else { return false }
        triggered = true
        return true
    }
}
