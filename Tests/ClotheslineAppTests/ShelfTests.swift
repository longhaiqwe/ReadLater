import XCTest
import AppKit
@testable import ClotheslineApp

final class ShelfTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func testManagedCopySurvivesSourceRemovalAndManifestReload() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("笔记.txt")
        try Data("稍后再读".utf8).write(to: source)
        let repo = try ShelfRepository(root: root.appendingPathComponent("shelf"))
        let report = await repo.importFiles([source])
        XCTAssertEqual(report.added, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let imported = await repo.all()
        let file = try XCTUnwrap(imported.first)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try String(contentsOf: repo.url(for: file), encoding: .utf8), "稍后再读")
        let restored = try ShelfRepository(root: root.appendingPathComponent("shelf"))
        let list = await restored.all()
        XCTAssertEqual(list, [file])
    }
    func testDuplicatesSameNamesAndReadState() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("a")
        let second = root.appendingPathComponent("b")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        let a = first.appendingPathComponent("阅读.md"), b = second.appendingPathComponent("阅读.md")
        try Data("一".utf8).write(to: a)
        try Data("二".utf8).write(to: b)
        let repo = try ShelfRepository(root: root.appendingPathComponent("shelf"))
        let result = await repo.importFiles([a, a, b])
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.duplicates, 1)
        let list = await repo.all()
        XCTAssertNotEqual(repo.url(for: list[0]), repo.url(for: list[1]))
        try await repo.setRead(list[0].id, true)
        let restored = try ShelfRepository(root: root.appendingPathComponent("shelf"))
        let read = await restored.all()
        XCTAssertTrue(read[0].isRead)
    }
    func testMissingFilesDirectoriesAndMalformedManifestPreserveData() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = root.appendingPathComponent("shelf")
        let repo = try ShelfRepository(root: storage)
        let report = await repo.importFiles([root.appendingPathComponent("missing.pdf"), root])
        XCTAssertEqual(report.errors.count, 2)
        XCTAssertEqual(report.added, 0)
        let data = Data("broken manifest".utf8)
        try data.write(to: storage.appendingPathComponent("shelf.json"))
        XCTAssertThrowsError(try ShelfRepository(root: storage))
        XCTAssertEqual(try Data(contentsOf: storage.appendingPathComponent("shelf.json")), data)
    }
    func testFileURLPasteboardRoundTripUsesRealFiles() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("带 空格的文件.txt")
        try Data("test".utf8).write(to: file)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(pasteboard.writeObjects([file as NSURL]))
        let result = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(result, [file])
    }
    func testFileDragTrackerDoesNotTreatStalePasteboardAsNewDrag() {
        var tracker = FileDragTracker()
        XCTAssertFalse(tracker.update(buttonDown: false, changeCount: 3, hasFileURLs: true))
        XCTAssertFalse(tracker.update(buttonDown: true, changeCount: 3, hasFileURLs: true))
        XCTAssertTrue(tracker.update(buttonDown: true, changeCount: 4, hasFileURLs: true))
        XCTAssertTrue(tracker.update(buttonDown: true, changeCount: 4, hasFileURLs: true))
        XCTAssertFalse(tracker.update(buttonDown: false, changeCount: 4, hasFileURLs: true))
        XCTAssertFalse(tracker.update(buttonDown: true, changeCount: 4, hasFileURLs: true))
    }
}
