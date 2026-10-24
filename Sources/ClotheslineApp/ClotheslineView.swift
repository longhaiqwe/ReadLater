import SwiftUI

/// Supply stable item IDs and any SwiftUI card body; no product services are required.
struct ClotheslineView<Item: Identifiable, Card: View>: View where Item.ID == UUID {
    @ObservedObject var state: RailState
    let items: [Item]
    let title: (Item) -> String
    @ViewBuilder var card: (Item, Bool) -> Card
    private var ordered: [Item] { state.ordered(items) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView(state.edge.vertical ? .vertical : .horizontal) {
                    if state.edge.vertical {
                        VStack(spacing: state.metrics.spacing) { cards }
                            .padding(.vertical, 24)
                            .frame(minWidth: geometry.size.width,
                                   minHeight: max(0, geometry.size.height - 56), alignment: .top)
                    } else {
                        HStack(spacing: state.metrics.spacing) { cards }
                            .padding(.horizontal, 24)
                            .padding(.top, state.edge == .top ? 32 : 50)
                            .padding(.bottom, state.edge == .top ? 50 : 32)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height,
                                   alignment: state.edge == .top ? .top : .bottom)
                    }
                }
                .scrollIndicators(.visible)
                .frame(height: state.edge.vertical ? max(0, geometry.size.height - 56) : geometry.size.height)
                .frame(maxHeight: .infinity, alignment: .top)

                ClotheslineShape(edge: state.edge)
                    .stroke(Color.secondary.opacity(0.65), lineWidth: 1.5)
                    .allowsHitTesting(false)
                // The transparent rope target lives above the scroll view.
                ClotheslineShape(edge: state.edge)
                    .stroke(.clear, lineWidth: 16)
                    .contentShape(ClotheslineShape(edge: state.edge).stroke(style: StrokeStyle(lineWidth: 16)))
                    .gesture(moveGesture)
                    .accessibilityHidden(true)

                controls.position(x: geometry.size.width / 2,
                    y: state.edge == .bottom ? 25 : geometry.size.height - 25)
            }
            .background { RailBackdrop() }
        }
        .coordinateSpace(name: "hangingRail")
        .onPreferenceChange(RailHitRects.self) { state.hitRects = $0 }
    }

    @ViewBuilder private var cards: some View {
        if items.isEmpty {
            Text("还没有内容").foregroundStyle(.secondary).padding(32)
        }
        ForEach(ordered) { item in
            HangingCard(state: state, id: item.id, title: title(item),
                        shift: { state.shift(item.id, by: $0, among: ordered.map(\.id)) }) {
                card(item, state.compact)
            }
        }
    }
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { if !state.locked { state.dragWindow?($0.translation, false) } }
            .onEnded { state.dragWindow?($0.translation, true) }
    }
    private var controls: some View {
        HStack(spacing: 10) {
            Image(systemName: state.locked ? "lock" : "arrow.up.and.down.and.arrow.left.and.right")
                .frame(width: 24, height: 24).contentShape(Rectangle()).gesture(moveGesture)
                .help(state.locked ? "位置已锁定" : "拖动到屏幕另一边")
                .accessibilityLabel("移动挂卡栏；也可在位置菜单选择屏幕边缘")
            Menu {
                ForEach(ScreenEdge.allCases, id: \.rawValue) { edge in
                    Button(edge.title) { state.edge = edge }.disabled(state.locked)
                }
                Toggle("锁定位置", isOn: $state.locked)
                Toggle("迷你挂卡", isOn: $state.compact)
            } label: { Image(systemName: "slider.horizontal.3") }
                .menuStyle(.borderlessButton).fixedSize().help("位置与显示")
            Button { state.pinned.toggle() } label: {
                Label(state.pinned ? "已固定" : "固定", systemImage: state.pinned ? "pin.fill" : "pin")
            }
            .accessibilityValue(state.pinned ? "已开启" : "已关闭")
            Button { state.hide(manually: true) } label: { Image(systemName: "xmark") }
                .help("收起挂卡栏").accessibilityLabel("收起挂卡栏")
        }
        .font(.system(size: 11)).buttonStyle(.plain)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .railInteractive()
    }
}

struct HangingCard<Content: View>: View {
    @ObservedObject var state: RailState
    let id: UUID
    let title: String
    let shift: (Int) -> Void
    @ViewBuilder var content: () -> Content
    @State private var hovered = false
    @State private var dragOffset = CGSize.zero
    @State private var push = 0.0
    @State private var pushedAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state.edge.vertical {
                HStack(spacing: -11) {
                    if state.edge == .left { sidePeg }
                    paper
                    if state.edge == .right { sidePeg }
                }
            } else {
                VStack(spacing: -11) {
                    if state.edge == .top { peg }
                    paper
                    if state.edge == .bottom { peg.rotationEffect(.degrees(180)) }
                }
            }
        }
        .railInteractive()
        .modifier(SwayingCard(motion: CardMotion(seed: id, live: state.visible, gustAt: state.gustAt,
                                               push: push, pushedAt: pushedAt),
                              edge: state.edge, calm: hovered || dragOffset != .zero ? 0 : 1))
        .offset(x: state.edge.vertical ? 0 : dragOffset.width,
                y: state.edge.vertical ? dragOffset.height : 0)
        .zIndex(dragOffset == .zero ? 0 : 2)
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAction(named: "前移") { shift(-1) }
        .accessibilityAction(named: "后移") { shift(1) }
    }
    // Reordering uses the peg only, so card buttons, text selection and scrolling keep working.
    private var reorder: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("hangingRail"))
            .onChanged {
                dragOffset = $0.translation
                push = CardMotion.dragTilt(velocity: $0.velocity, edge: state.edge)
                pushedAt = $0.time
            }
            .onEnded {
                let distance = state.edge.vertical ? $0.translation.height : $0.translation.width
                let dimension = state.edge.vertical ? state.cardSize.height : state.cardSize.width
                let update = {
                    if abs(distance) > dimension * 0.35 { shift(distance > 0 ? 1 : -1) }
                    dragOffset = .zero
                }
                if reduceMotion { update() }
                else { withAnimation(.spring(response: 0.32, dampingFraction: 0.8), update) }
            }
    }
    private var peg: some View {
        WoodenPeg().frame(width: 32, height: 29).contentShape(Rectangle())
            .gesture(reorder).help("拖动夹子调整顺序").zIndex(1)
    }
    private var sidePeg: some View {
        WoodenPeg().rotationEffect(.degrees(state.edge == .left ? -90 : 90))
            .frame(width: 29, height: 32).contentShape(Rectangle())
            .gesture(reorder).help("拖动夹子调整顺序").zIndex(1)
    }
    private var paper: some View {
        content()
            .frame(width: state.cardSize.width, height: state.cardSize.height)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }
}
