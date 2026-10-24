import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Own one controller for the lifetime of the application. Uses no event taps or permissions.
@MainActor
final class RailWindowController: NSObject, NSMenuDelegate {
    let state: RailState
    let panel: FloatingPanel
    private let title: String
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var hover = EdgeHoverTrigger()
    private var awaySince: TimeInterval?
    private var peekUntil: TimeInterval = 0
    private var menuOpen = false
    private var dragOrigin: NSPoint?
    private var dragMouse: NSPoint?
    private var detailWindow: NSWindow?
    private let acceptsFileDrops: Bool
    private var fileDrag = FileDragTracker()
    var additionalMenuItems: ((NSMenu) -> Void)?

    init<Content: View>(state: RailState, title: String, symbol: String,
                        onFileDrop: (([URL]) -> Void)? = nil,
                        @ViewBuilder content: () -> Content) {
        self.state = state
        self.title = title
        acceptsFileDrops = onFileDrop != nil
        panel = FloatingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        super.init()
        panel.title = title
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let onFileDrop {
            let host = FileDropHostingView(rootView: content())
            host.receiveFiles = onFileDrop
            host.targetingChanged = { [weak state] in state?.isDropTarget = $0 }
            panel.contentView = host
        } else { panel.contentView = NSHostingView(rootView: content()) }
        state.settingsChanged = { [weak self] in self?.place() }
        state.visibilityChanged = { [weak self] in self?.setVisible($0) }
        state.dragWindow = { [weak self] in self?.drag($0, ended: $1) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            ?? NSImage(systemSymbolName: "square.stack", accessibilityDescription: title)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = title
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.place() } })
        for (notification, open) in [(NSMenu.didBeginTrackingNotification, true), (NSMenu.didEndTrackingNotification, false)] {
            observers.append(NotificationCenter.default.addObserver(forName: notification, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor [weak self] in self?.menuOpen = open; self?.awaySince = nil }
            })
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        revealForInteraction()
    }
    func revealForInteraction() {
        state.reveal()
        peekUntil = ProcessInfo.processInfo.systemUptime + 10
    }
    func suspendForDialog() { menuOpen = true; panel.orderOut(nil) }
    func resumeAfterDialog() { menuOpen = false; state.reveal() }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        state.settingsChanged = nil
        state.visibilityChanged = nil
        state.dragWindow = nil
        panel.orderOut(nil)
        detailWindow?.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    private var screen: NSScreen? {
        let id = state.defaults.integer(forKey: "rail.screenID")
        return NSScreen.screens.first { screenID($0) == id } ?? NSScreen.main ?? NSScreen.screens.first
    }
    private func screenID(_ screen: NSScreen) -> Int {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
    }
    private func place() {
        guard let screen else { return }
        state.defaults.set(screenID(screen), forKey: "rail.screenID")
        let frame = state.edge.frame(screen: screen.frame, visible: screen.visibleFrame, cardSize: state.cardSize)
        panel.setFrame(frame, display: true)
        hover = EdgeHoverTrigger()
        awaySince = nil
    }
    private func setVisible(_ visible: Bool) {
        awaySince = nil
        if visible {
            place()
            peekUntil = ProcessInfo.processInfo.systemUptime + 1
            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
        } else {
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }
    private func tick() {
        let buttonsDown = NSEvent.pressedMouseButtons != 0
        let pasteboard = NSPasteboard(name: .drag)
        let draggingFiles = fileDrag.update(buttonDown: buttonsDown, changeCount: pasteboard.changeCount,
                                           hasFileURLs: pasteboard.types?.contains(.fileURL) == true) && acceptsFileDrops
        guard let screen, !menuOpen, dragOrigin == nil, !buttonsDown || draggingFiles else {
            hover = EdgeHoverTrigger()
            awaySince = nil
            return
        }
        let point = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        if hover.update(isAtEdge: state.edge.containsHoverPoint(point, screen: screen.frame), now: now), !state.visible {
            state.reveal()
        }
        if state.visible {
            // AppKit screen coordinates have a bottom-left origin; SwiftUI preferences use top-left.
            let local = CGPoint(x: point.x - panel.frame.minX, y: panel.frame.maxY - point.y)
            panel.ignoresMouseEvents = !draggingFiles && !RailInteraction.accepts(local, size: panel.frame.size,
                                                               edge: state.edge, hitRects: state.hitRects)
        }
        if buttonsDown { awaySince = nil; return }
        if state.visible, !state.pinned, now >= peekUntil,
           !state.edge.containsPanelPoint(point, panel: panel.frame, screen: screen.frame) {
            if awaySince == nil { awaySince = now }
            if now - (awaySince ?? now) >= 0.55 { state.hide() }
        } else { awaySince = nil }
    }
    private func drag(_ translation: CGSize, ended: Bool) {
        guard !state.locked else { dragOrigin = nil; dragMouse = nil; return }
        let mouse = NSEvent.mouseLocation
        if ended {
            dragOrigin = nil
            dragMouse = nil
            if let target = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
                state.defaults.set(screenID(target), forKey: "rail.screenID")
                state.edge = ScreenEdge.nearest(to: mouse, in: target.visibleFrame)
            }
            place()
            return
        }
        if dragOrigin == nil {
            dragOrigin = panel.frame.origin
            dragMouse = NSPoint(x: mouse.x - translation.width, y: mouse.y + translation.height)
        }
        if let origin = dragOrigin, let start = dragMouse {
            panel.setFrameOrigin(NSPoint(x: origin.x + mouse.x - start.x, y: origin.y + mouse.y - start.y))
        }
    }
    /// Hide the rail before opening a normal window, so status-bar-level cards cannot cover it.
    func showDetail<Content: View>(title: String, @ViewBuilder content: () -> Content) {
        state.hide(manually: true)
        if detailWindow == nil {
            detailWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                                    styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            detailWindow?.isReleasedWhenClosed = false
            detailWindow?.center()
        }
        detailWindow?.title = title
        detailWindow?.contentView = NSHostingView(rootView: content())
        detailWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        func add(_ title: String, _ selector: Selector, checked: Bool? = nil) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            if let checked { item.state = checked ? .on : .off }
            menu.addItem(item)
        }
        additionalMenuItems?(menu)
        add(state.visible ? "收起挂卡栏" : "展开挂卡栏", #selector(toggleVisible))
        add("固定展开", #selector(togglePinned), checked: state.pinned)
        add("迷你挂卡", #selector(toggleCompact), checked: state.compact)
        add("锁定位置", #selector(toggleLocked), checked: state.locked)
        let positions = NSMenu()
        for edge in ScreenEdge.allCases {
            let item = NSMenuItem(title: edge.title, action: #selector(changeEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge.rawValue
            item.state = edge == state.edge ? .on : .off
            item.isEnabled = !state.locked
            positions.addItem(item)
        }
        positions.autoenablesItems = false
        let position = NSMenuItem(title: "屏幕边缘", action: nil, keyEquivalent: "")
        position.submenu = positions
        menu.addItem(position)
        menu.addItem(.separator())
        add("退出 \(title)", #selector(quit))
    }
    @objc private func toggleVisible() { if state.visible { state.hide(manually: true) } else { state.reveal() } }
    @objc private func togglePinned() { state.pinned.toggle() }
    @objc private func toggleCompact() { state.compact.toggle() }
    @objc private func toggleLocked() { state.locked.toggle() }
    @objc private func changeEdge(_ sender: NSMenuItem) {
        guard !state.locked, let raw = sender.representedObject as? String, let edge = ScreenEdge(rawValue: raw) else { return }
        state.edge = edge
        state.reveal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
