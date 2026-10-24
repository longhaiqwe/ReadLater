import AppKit
import SwiftUI
import Quartz

@MainActor
final class ShelfStore: NSObject, ObservableObject {
    @Published private(set) var files: [ShelfFile] = []
    @Published private(set) var importing = false
    @Published var message = "拖入文件，留待稍后"
    @Published var error: String?
    let repository: ShelfRepository
    private var previewWindow: NSWindow?
    var prepareFileDialog: (() -> Void)?
    var finishFileDialog: (() -> Void)?

    init(root: URL) throws { repository = try ShelfRepository(root: root); super.init() }
    func load() async { files = await repository.all() }
    func url(_ file: ShelfFile) -> URL { repository.url(for: file) }
    func accept(_ urls: [URL]) {
        guard !importing else { message = "正在保存文件，请稍后再拖入"; return }
        importing = true
        message = "正在保存 \(urls.count) 个文件…"
        Task {
            let report = await repository.importFiles(urls)
            await load()
            importing = false
            message = report.added > 0 ? "已暂存 \(report.added) 个文件" : "没有新增文件"
            if report.duplicates > 0 { message += " · \(report.duplicates) 个已在架上" }
            if !report.errors.isEmpty { error = report.errors.joined(separator: "\n") }
        }
    }
    func chooseFiles() {
        prepareFileDialog?()
        let picker = NSOpenPanel()
        picker.canChooseFiles = true
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = true
        picker.prompt = "暂存文件"
        picker.message = "保留独立副本，原文件不会被移动。"
        NSApp.activate(ignoringOtherApps: true)
        let response = picker.runModal()
        finishFileDialog?()
        if response == .OK { accept(picker.urls) }
    }
    func open(_ file: ShelfFile) {
        guard FileManager.default.fileExists(atPath: url(file).path) else { error = "暂存副本已丢失，请重新拖入这个文件。"; return }
        NSWorkspace.shared.open(url(file))
    }
    func reveal(_ file: ShelfFile) { NSWorkspace.shared.activateFileViewerSelecting([url(file)]) }
    func toggleRead(_ file: ShelfFile) {
        Task {
            do { try await repository.setRead(file.id, !file.isRead); await load() }
            catch { self.error = error.localizedDescription }
        }
    }
    func remove(_ file: ShelfFile) {
        Task {
            do { try await repository.remove(file.id); await load(); message = "暂存副本已移到废纸篓" }
            catch { self.error = error.localizedDescription }
        }
    }
    func preview(_ file: ShelfFile) {
        guard FileManager.default.fileExists(atPath: url(file).path) else { error = "暂存副本已丢失，请重新拖入。"; return }
        if previewWindow == nil {
            previewWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                                     styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            previewWindow?.isReleasedWhenClosed = false
            previewWindow?.center()
        }
        guard let window = previewWindow,
              let preview = QLPreviewView(frame: NSRect(x: 0, y: 0, width: 760, height: 600), style: .normal) else { return }
        preview.previewItem = url(file) as NSURL
        window.title = "\(file.name) · 稍后阅读"
        window.contentView = preview
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
