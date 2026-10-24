import AppKit
import SwiftUI

/// Optional native file intake; business code decides whether to copy, index or process the URLs.
final class FileDropHostingView<Content: View>: NSHostingView<Content> {
    var receiveFiles: (([URL]) -> Void)?
    var targetingChanged: ((Bool) -> Void)?
    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("Use init(rootView:)") }
    private func urls(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepts = !urls(sender).isEmpty
        targetingChanged?(accepts)
        return accepts ? .copy : []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { urls(sender).isEmpty ? [] : .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { targetingChanged?(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { !urls(sender).isEmpty }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = urls(sender)
        targetingChanged?(false)
        guard !files.isEmpty, let receiveFiles else { return false }
        receiveFiles(files)
        return true
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { targetingChanged?(false) }
}

/// A stale drag pasteboard must not turn an ordinary held click into a file drag.
struct FileDragTracker {
    private var idleChangeCount: Int?
    private var active = false
    mutating func update(buttonDown: Bool, changeCount: Int, hasFileURLs: Bool) -> Bool {
        if !buttonDown {
            idleChangeCount = changeCount
            active = false
            return false
        }
        if hasFileURLs, let idleChangeCount, changeCount != idleChangeCount { active = true }
        return active
    }
}
