import SwiftUI
import AppKit

/// Native material; colors follow the host application appearance.
struct RailGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct RailBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            if !reduceTransparency { RailGlass() }
            Color(nsColor: .windowBackgroundColor).opacity(reduceTransparency ? 1 : 0.55)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.55), lineWidth: 1))
        .padding(4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct RailHitRects: PreferenceKey {
    static var defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

enum RailInteraction {
    static func accepts(_ point: CGPoint, size: CGSize, edge: ScreenEdge, hitRects: [CGRect]) -> Bool {
        guard CGRect(origin: .zero, size: size).contains(point) else { return false }
        if hitRects.contains(where: { $0.insetBy(dx: -8, dy: -8).contains(point) }) { return true }
        if edge.vertical { return point.y < size.height - 56 }
        // The rope remains draggable and the scrollbar remains usable between cards.
        let ropeDistance = edge == .top ? point.y : size.height - point.y
        return ropeDistance <= 48 || point.y >= size.height - 16
    }
}

extension View {
    func railInteractive() -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: RailHitRects.self, value: [geometry.frame(in: .named("hangingRail"))])
        })
    }
}

extension ScreenEdge {
    var pegAnchor: UnitPoint {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }
}

struct CardMotion {
    var seed: UUID
    var live: Bool
    var gustAt: Date = .distantPast
    var push: Double = 0
    var pushedAt: Date = .distantPast
    func degrees(at time: TimeInterval, calm: Double = 1) -> Double {
        guard live else { return 0 }
        let bytes = seed.uuid
        // Mix UUID bytes so stable item identities produce distinct motion.
        let frequency = 2 * Double.pi / (3.4 + Double((bytes.1 ^ bytes.15) % 8) * 0.2)
        let phase = Double(bytes.2 &+ (bytes.15 &* 73)) / 255 * 2 * .pi
        var degrees = calm * (0.9 * sin(frequency * time + phase) + 0.3 * sin(2.3 * frequency * time + phase * 1.7))
        let gust = time - gustAt.timeIntervalSinceReferenceDate
        if gust > 0 { degrees += 3.2 * exp(-gust / 0.6) * sin(2 * .pi * gust) }
        let settle = max(0, time - pushedAt.timeIntervalSinceReferenceDate - 0.05)
        degrees += push * exp(-settle / 0.35) * cos(2 * .pi * settle / 0.9)
        return degrees
    }
    static func pivot(size: CGSize, edge: ScreenEdge) -> CGPoint {
        CGPoint(x: size.width * edge.pegAnchor.x, y: size.height * edge.pegAnchor.y)
    }
    static func dragTilt(velocity: CGSize, edge: ScreenEdge) -> Double {
        let speed = edge.vertical ? velocity.height : velocity.width
        guard speed.isFinite else { return 0 }
        let sign: Double = edge == .bottom || edge == .left ? -1 : 1
        return sign * max(-8, min(8, Double(speed) / 100))
    }
}

struct SwayingCard: ViewModifier {
    var motion: CardMotion
    var edge: ScreenEdge
    var calm: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion || !motion.live { content }
        else {
            TimelineView(.animation(minimumInterval: 1 / 60)) { context in
                content.modifier(CardSwing(time: context.date.timeIntervalSinceReferenceDate, motion: motion, edge: edge, calm: calm))
            }
        }
    }
}

private struct CardSwing: GeometryEffect {
    var time: TimeInterval
    var motion: CardMotion
    var edge: ScreenEdge
    var calm: Double
    var animatableData: Double {
        get { calm }
        set { calm = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let pivot = CardMotion.pivot(size: size, edge: edge)
        return ProjectionTransform(CGAffineTransform(translationX: pivot.x, y: pivot.y)
            .rotated(by: motion.degrees(at: time, calm: calm) * .pi / 180)
            .translatedBy(x: -pivot.x, y: -pivot.y))
    }
}
