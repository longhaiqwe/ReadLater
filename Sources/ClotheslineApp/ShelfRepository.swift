import Foundation
import CryptoKit

struct ShelfFile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let addedAt: Date
    let byteCount: Int64
    let digest: String
    var isRead: Bool
}

struct ImportReport: Sendable {
    var added = 0
    var duplicates = 0
    var errors: [String] = []
}

/// The actor serializes all manifest mutations. File IO never blocks the UI actor.
actor ShelfRepository {
    let root: URL
    private var files: [ShelfFile]
    private let manager = FileManager.default
    private var manifest: URL { root.appendingPathComponent("shelf.json") }
    private var storage: URL { root.appendingPathComponent("Files", isDirectory: true) }

    init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Files"), withIntermediateDirectories: true)
        let manifest = root.appendingPathComponent("shelf.json")
        if FileManager.default.fileExists(atPath: manifest.path) {
            // A malformed manifest must not be silently replaced with an empty shelf.
            files = try JSONDecoder().decode([ShelfFile].self, from: Data(contentsOf: manifest))
            guard Set(files.map(\.id)).count == files.count,
                  files.allSatisfy({ !$0.name.isEmpty && $0.name != "." && $0.name != ".." && !$0.name.contains("/") }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        } else { files = [] }
    }
    func all() -> [ShelfFile] { files }
    nonisolated func url(for file: ShelfFile) -> URL {
        root.appendingPathComponent("Files").appendingPathComponent(file.id.uuidString)
            .appendingPathComponent(file.name)
    }
    private func save(_ updated: [ShelfFile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: manifest, options: .atomic)
        files = updated
    }
    func importFiles(_ urls: [URL]) -> ImportReport {
        var report = ImportReport()
        for input in urls {
            do {
                guard input.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
                let access = input.startAccessingSecurityScopedResource()
                defer { if access { input.stopAccessingSecurityScopedResource() } }
                let source = input.resolvingSymlinksInPath()
                let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard values.isRegularFile == true else {
                    report.errors.append("\(input.lastPathComponent)：暂不支持文件夹")
                    continue
                }
                let id = UUID()
                let folder = storage.appendingPathComponent(id.uuidString, isDirectory: true)
                try manager.createDirectory(at: folder, withIntermediateDirectories: false)
                do {
                    let copy = folder.appendingPathComponent(source.lastPathComponent)
                    try manager.copyItem(at: source, to: copy)
                    // Hash the copy so it matches the bytes we actually retained.
                    let digest = try Self.hash(copy)
                    if files.contains(where: { $0.digest == digest && manager.fileExists(atPath: url(for: $0).path) }) {
                        try manager.removeItem(at: folder)
                        report.duplicates += 1
                        continue
                    }
                    let file = ShelfFile(id: id, name: source.lastPathComponent, addedAt: Date(),
                                         byteCount: Int64(try copy.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0),
                                         digest: digest, isRead: false)
                    try save(files + [file])
                    report.added += 1
                } catch {
                    try? manager.removeItem(at: folder)
                    throw error
                }
            } catch { report.errors.append("\(input.lastPathComponent)：\(error.localizedDescription)") }
        }
        return report
    }
    func setRead(_ id: UUID, _ read: Bool) throws {
        var updated = files
        guard let index = updated.firstIndex(where: { $0.id == id }) else { return }
        updated[index].isRead = read
        try save(updated)
    }
    /// Only the managed copy goes to Trash. A manifest failure restores the file when possible.
    func remove(_ id: UUID) throws {
        guard let file = files.first(where: { $0.id == id }) else { return }
        let stored = url(for: file)
        var trashURL: NSURL?
        let exists = manager.fileExists(atPath: stored.path)
        if exists { try manager.trashItem(at: stored, resultingItemURL: &trashURL) }
        do { try save(files.filter { $0.id != id }) }
        catch {
            if let trashURL { try? manager.moveItem(at: trashURL as URL, to: stored) }
            throw error
        }
        try? manager.removeItem(at: stored.deletingLastPathComponent())
    }
    static func hash(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
