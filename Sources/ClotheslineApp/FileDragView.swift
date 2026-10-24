import AppKit
import SwiftUI
import QuickLookThumbnailing

/// NSURL pasteboard writers make this a real file drag for Finder and document applications.
struct FileDragView: NSViewRepresentable {
    let url: URL
    let preview: () -> Void
    func makeNSView(context: Context) -> FileDragImageView {
        let view = FileDragImageView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.masksToBounds = true
        return view
    }
    func updateNSView(_ view: FileDragImageView, context: Context) {
        view.preview = preview
        guard view.fileURL != url else { return }
        view.fileURL = url
        view.image = NSWorkspace.shared.icon(forFile: url.path)
        view.setAccessibilityLabel("\(url.lastPathComponent)，拖到其他应用使用，双击预览")
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 360, height: 200),
                                                   scale: 2, representationTypes: .all)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak view] thumbnail, _ in
            DispatchQueue.main.async {
                guard let view, view.fileURL == url, let thumbnail else { return }
                view.image = thumbnail.nsImage
            }
        }
    }
}

final class FileDragImageView: NSView, NSDraggingSource {
    var image: NSImage? { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        guard let image, image.size.width > 0, image.size.height > 0 else { return }
        let ratio = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let rect = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                          width: size.width, height: size.height)
        image.draw(in: rect)
    }

    var fileURL: URL?
    var preview: (() -> Void)?
    private var start: NSPoint?
    private var didDrag = false
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        didDrag = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard !didDrag, let fileURL, let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) > 4 else { return }
        didDrag = true
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let icon = image ?? NSWorkspace.shared.icon(forFile: fileURL.path)
        item.setDraggingFrame(bounds, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }
    override func mouseUp(with event: NSEvent) {
        if !didDrag && event.clickCount == 2 { preview?() }
        start = nil
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
