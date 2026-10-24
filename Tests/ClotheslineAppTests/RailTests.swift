import XCTest
@testable import ClotheslineApp

private struct TestItem: Identifiable { let id: UUID; let title: String }

final class RailTests: XCTestCase {
    func testAllEdgesFitVisibleFramesIncludingNegativeMonitorCoordinates() {
        let screen = CGRect(x: -1440, y: -100, width: 1440, height: 900)
        let visible = CGRect(x: -1390, y: -60, width: 1390, height: 830)
        for edge in ScreenEdge.allCases {
            for compact in [false, true] {
                let frame = edge.frame(screen: screen, visible: visible,
                                       cardSize: RailMetrics().cardSize(compact: compact))
                XCTAssertTrue(visible.contains(frame), "\(edge)")
                if edge.vertical { XCTAssertEqual(frame.height, visible.height) }
                else { XCTAssertEqual(frame.width, visible.width) }
            }
        }
    }
    func testPhysicalBoundaryIsIncludedAndAdjacentMonitorExcluded() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertTrue(ScreenEdge.top.containsHoverPoint(CGPoint(x: 500, y: 900), screen: screen))
        XCTAssertTrue(ScreenEdge.right.containsHoverPoint(CGPoint(x: 1440, y: 400), screen: screen))
        XCTAssertFalse(ScreenEdge.right.containsHoverPoint(CGPoint(x: 1441, y: 400), screen: screen))
        XCTAssertFalse(ScreenEdge.left.containsHoverPoint(CGPoint(x: -1, y: 400), screen: screen))
    }
    func testDwellTriggersOnceAndResetsAfterLeavingEdge() {
        var hover = EdgeHoverTrigger()
        XCTAssertFalse(hover.update(isAtEdge: true, now: 0))
        XCTAssertFalse(hover.update(isAtEdge: true, now: 0.2))
        XCTAssertTrue(hover.update(isAtEdge: true, now: 0.31))
        XCTAssertFalse(hover.update(isAtEdge: true, now: 2))
        XCTAssertFalse(hover.update(isAtEdge: false, now: 3))
        XCTAssertFalse(hover.update(isAtEdge: true, now: 4))
        XCTAssertTrue(hover.update(isAtEdge: true, now: 4.31))
    }
    func testMenuBarAndDockGapKeepPanelOpen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 0, y: 60, width: 1440, height: 810)
        let top = ScreenEdge.top.frame(screen: screen, visible: visible, cardSize: RailMetrics().standard)
        let bottom = ScreenEdge.bottom.frame(screen: screen, visible: visible, cardSize: RailMetrics().standard)
        XCTAssertTrue(ScreenEdge.top.containsPanelPoint(CGPoint(x: 500, y: 895), panel: top, screen: screen))
        XCTAssertTrue(ScreenEdge.bottom.containsPanelPoint(CGPoint(x: 500, y: 10), panel: bottom, screen: screen))
        XCTAssertFalse(ScreenEdge.top.containsPanelPoint(CGPoint(x: 500, y: 100), panel: top, screen: screen))
    }
    @MainActor
    func testPinPersistenceExplicitHideAndIndependentLock() {
        let suite = "clothesline.test.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = RailState(defaults: defaults)
        state.pinned = true
        XCTAssertTrue(state.visible)
        XCTAssertFalse(state.locked)
        XCTAssertFalse(state.hide())
        let restored = RailState(defaults: defaults)
        XCTAssertTrue(restored.pinned)
        XCTAssertTrue(restored.visible)
        XCTAssertTrue(restored.hide(manually: true))
        XCTAssertFalse(restored.visible)
        XCTAssertFalse(RailState(defaults: defaults).pinned)
    }
    @MainActor
    func testOrderSurvivesRestartAndHandlesInsertedAndRemovedItems() {
        let suite = "clothesline.test.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = RailState(defaults: defaults)
        let items = (0..<3).map { TestItem(id: UUID(), title: "任务 \($0)") }
        state.shift(items[0].id, by: 1, among: items.map(\.id))
        let restored = RailState(defaults: defaults)
        XCTAssertEqual(restored.ordered(items).map(\.id), [items[1].id, items[0].id, items[2].id])
        let new = TestItem(id: UUID(), title: "新任务")
        XCTAssertEqual(restored.ordered([items[2], new, items[1]]).map(\.id), [items[1].id, items[2].id, new.id])
        restored.shift(items[1].id, by: -1, among: restored.ordered(items).map(\.id))
        XCTAssertEqual(restored.ordered(items).first?.id, items[1].id)
    }
    @MainActor
    func testRepeatedRevealDoesNotRestartGust() {
        let suite = "clothesline.test.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = RailState(defaults: defaults)
        var events: [Bool] = []
        state.visibilityChanged = { events.append($0) }
        state.reveal()
        let first = state.gustAt
        state.reveal()
        XCTAssertEqual(first, state.gustAt)
        state.hide()
        XCTAssertEqual(events, [true, true, false])
    }
    func testHitRegionsKeepCardsAndControlsInteractiveButPassHorizontalGapsThrough() {
        let size = CGSize(width: 1000, height: 322)
        let rects = [CGRect(x: 24, y: 32, width: 264, height: 238), CGRect(x: 400, y: 280, width: 200, height: 34)]
        XCTAssertTrue(RailInteraction.accepts(CGPoint(x: 100, y: 100), size: size, edge: .top, hitRects: rects))
        XCTAssertTrue(RailInteraction.accepts(CGPoint(x: 500, y: 295), size: size, edge: .top, hitRects: rects))
        XCTAssertFalse(RailInteraction.accepts(CGPoint(x: 350, y: 100), size: size, edge: .top, hitRects: rects))
        XCTAssertTrue(RailInteraction.accepts(CGPoint(x: 350, y: 20), size: size, edge: .top, hitRects: rects))
        XCTAssertTrue(RailInteraction.accepts(CGPoint(x: 350, y: 318), size: size, edge: .top, hitRects: rects))
    }
    func testMotionStopsWhenHiddenAndGustDecays() {
        let date = Date(timeIntervalSinceReferenceDate: 100)
        var motion = CardMotion(seed: UUID(), live: true, gustAt: date, push: 8, pushedAt: date)
        XCTAssertGreaterThan(abs(motion.degrees(at: 100.1, calm: 0)), 1)
        XCTAssertLessThan(abs(motion.degrees(at: 110, calm: 0)), 0.001)
        motion.live = false
        XCTAssertEqual(motion.degrees(at: 100.1), 0)
        for edge in ScreenEdge.allCases {
            XCTAssertEqual(abs(CardMotion.dragTilt(velocity: CGSize(width: 5000, height: 5000), edge: edge)), 8)
            XCTAssertEqual(CardMotion.dragTilt(velocity: CGSize(width: CGFloat.infinity, height: CGFloat.infinity), edge: edge), 0)
        }
    }
    func testPivotMatchesEachPeg() {
        let size = CGSize(width: 264, height: 220)
        XCTAssertEqual(CardMotion.pivot(size: size, edge: .top), CGPoint(x: 132, y: 0))
        XCTAssertEqual(CardMotion.pivot(size: size, edge: .bottom), CGPoint(x: 132, y: 220))
        XCTAssertEqual(CardMotion.pivot(size: size, edge: .left), CGPoint(x: 0, y: 110))
        XCTAssertEqual(CardMotion.pivot(size: size, edge: .right), CGPoint(x: 264, y: 110))
    }
}
