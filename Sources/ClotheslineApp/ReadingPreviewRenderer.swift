import AppKit
import SwiftUI

/// Reproducible screenshots of the real views, using isolated fixture files and preferences.
@MainActor
enum ReadingPreviewRenderer {
    static func render(fixtures: URL, output: URL) async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reading-preview-\(UUID())")
        let suite = "reading.preview.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let store = try ShelfStore(root: root)
        let files = try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil).filter { !$0.lastPathComponent.hasPrefix(".") }
        _ = await store.repository.importFiles(files.sorted { $0.lastPathComponent < $1.lastPathComponent })
        await store.load()
        for (edge, compact, dark, name) in [
            (ScreenEdge.top, false, false, "04-readlater-overview"),
            (.bottom, false, true, "05-readlater-dark"),
            (.left, true, false, "06-readlater-side")
        ] {
            let state = RailState(defaults: defaults, metrics: RailMetrics(standard: CGSize(width: 244, height: 270), compact: CGSize(width: 214, height: 204), spacing: 20))
            state.edge = edge
            state.compact = compact
            let size = edge.vertical ? CGSize(width: 286, height: 1050) : CGSize(width: 1200, height: 372)
            let host = NSHostingView(rootView: ReadingRail(state: state, store: store).environment(\.colorScheme, dark ? .dark : .light))
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = host
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            // Let Quick Look complete asynchronous thumbnails before capturing the views.
            try await Task.sleep(nanoseconds: 2_000_000_000)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            window.close()
        }
    }
}
