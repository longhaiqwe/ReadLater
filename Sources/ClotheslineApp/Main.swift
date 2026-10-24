import AppKit
import SwiftUI

@MainActor
final class ReadingAppDelegate: NSObject, NSApplicationDelegate {
    private var rail: RailWindowController?
    private var store: ShelfStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("稍后阅读", isDirectory: true)
            let store = try ShelfStore(root: root)
            self.store = store
            let defaults: UserDefaults = Bundle.main.bundleIdentifier == nil
                ? UserDefaults(suiteName: "local.clothesline.readlater.development") ?? .standard : .standard
            if defaults.object(forKey: "rail.edge") == nil { defaults.set("bottom", forKey: "rail.edge") }
            if defaults.object(forKey: "rail.pinned") == nil { defaults.set(true, forKey: "rail.pinned") }
            let state = RailState(defaults: defaults,
                                  metrics: RailMetrics(standard: CGSize(width: 244, height: 270),
                                                       compact: CGSize(width: 214, height: 204), spacing: 20))
            rail = RailWindowController(state: state, title: "稍后阅读", symbol: "books.vertical",
                                        onFileDrop: { [weak store] in store?.accept($0) }) {
                ReadingRail(state: state, store: store)
            }
            store.prepareFileDialog = { [weak self] in self?.rail?.suspendForDialog() }
            store.finishFileDialog = { [weak self] in self?.rail?.resumeAfterDialog() }
            rail?.additionalMenuItems = { [weak self] menu in
                let item = NSMenuItem(title: "添加文件…", action: #selector(ReadingAppDelegate.addFiles), keyEquivalent: "o")
                item.target = self
                menu.addItem(item)
                menu.addItem(.separator())
            }
            Task { await store.load() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "暂存记录无法读取"
            alert.informativeText = "已有文件会保留，请先检查存储目录。\n\(error.localizedDescription)"
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
    @objc private func addFiles() { store?.chooseFiles() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        rail?.revealForInteraction()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { rail?.stop() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct ClotheslineEntry {
    @MainActor static func main() {
        let app = NSApplication.shared
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"),
           CommandLine.arguments.indices.contains(index + 2) {
            let fixtures = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            let output = URL(fileURLWithPath: CommandLine.arguments[index + 2])
            Task { @MainActor in
                do { try await ReadingPreviewRenderer.render(fixtures: fixtures, output: output); exit(0) }
                catch { fputs("\(error)\n", stderr); exit(1) }
            }
            app.run()
            return
        }
        let delegate = ReadingAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
