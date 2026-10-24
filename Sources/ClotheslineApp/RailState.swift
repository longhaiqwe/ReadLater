import SwiftUI

struct RailMetrics {
    var standard = CGSize(width: 264, height: 220)
    var compact = CGSize(width: 224, height: 156)
    var spacing: CGFloat = 24
    func cardSize(compact: Bool) -> CGSize { compact ? self.compact : standard }
}

/// Presentation state only. Product data belongs in the host application's model.
@MainActor
final class RailState: ObservableObject {
    let defaults: UserDefaults
    let metrics: RailMetrics
    @Published var edge: ScreenEdge {
        didSet { defaults.set(edge.rawValue, forKey: "rail.edge"); settingsChanged?() }
    }
    @Published var compact: Bool {
        didSet { defaults.set(compact, forKey: "rail.compact"); settingsChanged?() }
    }
    @Published var locked: Bool {
        didSet { defaults.set(locked, forKey: "rail.locked") }
    }
    @Published var pinned: Bool {
        didSet { defaults.set(pinned, forKey: "rail.pinned"); if pinned { reveal() } }
    }
    @Published private(set) var visible = false
    @Published private(set) var gustAt = Date.distantPast
    @Published private(set) var order: [UUID] {
        didSet { defaults.set(order.map(\.uuidString), forKey: "rail.order") }
    }
    @Published var isDropTarget = false
    var hitRects: [CGRect] = []
    var settingsChanged: (() -> Void)?
    var visibilityChanged: ((Bool) -> Void)?
    var dragWindow: ((CGSize, Bool) -> Void)?

    init(defaults: UserDefaults, metrics: RailMetrics = RailMetrics()) {
        self.defaults = defaults
        self.metrics = metrics
        edge = ScreenEdge(rawValue: defaults.string(forKey: "rail.edge") ?? "") ?? .top
        compact = defaults.bool(forKey: "rail.compact")
        locked = defaults.bool(forKey: "rail.locked")
        pinned = defaults.bool(forKey: "rail.pinned")
        order = (defaults.stringArray(forKey: "rail.order") ?? []).compactMap(UUID.init(uuidString:))
        visible = pinned
    }
    var cardSize: CGSize { metrics.cardSize(compact: compact) }

    func reveal() {
        if !visible { gustAt = Date() }
        visible = true
        visibilityChanged?(true)
    }
    @discardableResult func hide(manually: Bool = false) -> Bool {
        guard manually || !pinned else { return false }
        if manually { pinned = false }
        visible = false
        visibilityChanged?(false)
        return true
    }
    func ordered<Item: Identifiable>(_ items: [Item]) -> [Item] where Item.ID == UUID {
        let ranks = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
        return items.enumerated().sorted {
            let lhs = ranks[$0.element.id] ?? order.count + $0.offset
            let rhs = ranks[$1.element.id] ?? order.count + $1.offset
            return lhs < rhs
        }.map(\.element)
    }
    func shift(_ id: UUID, by offset: Int, among ids: [UUID]) {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        var updated = ids
        updated.swapAt(index, index + offset)
        order = updated
    }
}
