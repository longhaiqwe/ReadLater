import SwiftUI

struct ReadingItem: Identifiable {
    static let intakeID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    let file: ShelfFile?
    var id: UUID { file?.id ?? Self.intakeID }
}

struct ReadingRail: View {
    @ObservedObject var state: RailState
    @ObservedObject var store: ShelfStore
    var body: some View {
        ClotheslineView(state: state, items: [ReadingItem(file: nil)] + store.files.map { ReadingItem(file: $0) },
                        title: { $0.file?.name ?? "稍后阅读，添加文件" }) { item, compact in
            if let file = item.file { ReadingCard(file: file, store: store, compact: compact) }
            else { IntakeCard(store: store, targeted: state.isDropTarget, compact: compact) }
        }
        .overlay {
            if state.isDropTarget {
                RoundedRectangle(cornerRadius: 18).stroke(Color.accentColor, lineWidth: 3).padding(5)
                    .allowsHitTesting(false)
            }
        }
        .tint(Color(red: 0.22, green: 0.45, blue: 0.40))
        .alert("文件暂存提示", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct IntakeCard: View {
    @ObservedObject var store: ShelfStore
    var targeted: Bool
    var compact: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            HStack {
                Label("稍后阅读", systemImage: "books.vertical").font(.headline)
                Spacer()
                Text("\(store.files.count)").font(.caption.monospacedDigit())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.primary.opacity(0.06), in: Capsule())
            }
            Spacer(minLength: 0)
            Image(systemName: targeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                .font(.system(size: compact ? 26 : 32, weight: .light)).foregroundStyle(.tint)
            Text(targeted ? "松手，留在这里" : "现在放下，稍后再读")
                .font(.system(size: compact ? 15 : 18, weight: .semibold))
            Text(store.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
            HStack {
                Button(action: store.chooseFiles) { Label("添加文件", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).controlSize(.small).disabled(store.importing)
                Spacer()
                if store.importing { ProgressView().controlSize(.small) }
            }
            if !compact { Text("保存独立副本 · 拖出继续使用").font(.system(size: 10)).foregroundStyle(.secondary) }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.accentColor.opacity(targeted ? 0.12 : 0.04))
    }
}

struct ReadingCard: View {
    let file: ShelfFile
    @ObservedObject var store: ShelfStore
    let compact: Bool
    private var type: String { (file.name as NSString).pathExtension.uppercased() }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack {
                Text(type.isEmpty ? "文件" : type).font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button { store.toggleRead(file) } label: {
                    Label(file.isRead ? "已读" : "待读", systemImage: file.isRead ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10)).foregroundStyle(file.isRead ? Color.accentColor : .secondary)
                }.buttonStyle(.plain).help("切换已读状态")
            }
            FileDragView(url: store.url(file)) { store.preview(file) }
                .frame(height: compact ? 56 : 104)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                .help("拖动预览到 Finder 或其他应用；双击预览")
            Text(file.name).font(.system(size: compact ? 12 : 13, weight: .semibold))
                .lineLimit(2).truncationMode(.middle).help(file.name)
            HStack {
                Text(ByteCountFormatter.string(fromByteCount: file.byteCount, countStyle: .file))
                Text("·")
                Text(file.addedAt, style: .date)
            }.font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Button("预览") { store.preview(file) }.help("Quick Look 预览")
                Button("打开") { store.open(file) }.help("用默认应用打开")
                Spacer()
                Menu {
                    Button(file.isRead ? "标记为未读" : "标记为已读") { store.toggleRead(file) }
                    Button("在 Finder 中显示") { store.reveal(file) }
                    Divider()
                    Button("移除暂存副本", role: .destructive) { store.remove(file) }
                } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize().help("文件操作，移除不影响原文件")
            }.font(.caption).buttonStyle(.plain)
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
