import SwiftUI


/// The row of space icons at the foot of the sidebar.
///
/// Icons only, centred, with the one you are in marked. No names: a
/// strip of names does not fit, and the name of the space you are in is
/// already at the top of its list. It renders and asks; switching means
/// choosing which tab becomes active, which lives in `ContentView`.
/// What the rail needs to know about the things it draws.
///
/// The icon is deliberately not here. The caller hands the rail a whole
/// cell, so the rail never learns what a space is, what its icon is made
/// of, or what happens when you right-click one. It knows a name to show
/// on hover and a colour for the mark, and that is the whole contract.
public protocol IconRailItem: Identifiable {
    var name: String { get }
    var tint: Color { get }
}


/// A row of equally pitched cells with the current one marked, centred
/// while it fits and scrolling once it does not.
///
/// It owns the geometry and nothing else: the pitch, the mark that slides
/// on that same pitch, and the name that appears over the cell you are
/// pointing at. Selection, dragging and menus belong to whoever supplies
/// the cells, which is why the payload format for a drag is not a concern
/// here: this row sits under a list that drags its own rows, and only the
/// caller knows how to tell the two apart.
public struct IconRail<Item: IconRailItem, Cell: View>: View {
    /// Watched by the mark and by nothing else in here. The cells are
    /// buttons with a menu, a popover and a sheet hanging off each of
    /// them; rebuilding all that a hundred times a second to move a
    /// rounded rectangle would be the most expensive way to look
    /// responsive.
    @ObservedObject var swipe: RailSwipeModel
    let items: [Item]
    let activeID: Item.ID
    /// One cell: its width and the gap after it. The mark is laid out on
    /// the same pitch, so the two cannot drift apart.
    var iconWidth: CGFloat = 26
    var gap: CGFloat = 2
    /// The hover label's fill and edge. Defaulted to the system's own so
    /// the rail looks right with nothing passed; an app with its own
    /// surface colours passes them and keeps its look.
    var labelBackground: Color = Color(nsColor: .controlBackgroundColor)
    var labelBorder: Color = Color(nsColor: .separatorColor)
    @ViewBuilder var cell: (Item) -> Cell

    public init(
        swipe: RailSwipeModel,
        items: [Item],
        activeID: Item.ID,
        iconWidth: CGFloat = 26,
        gap: CGFloat = 2,
        labelBackground: Color = Color(nsColor: .controlBackgroundColor),
        labelBorder: Color = Color(nsColor: .separatorColor),
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self.swipe = swipe
        self.items = items
        self.activeID = activeID
        self.iconWidth = iconWidth
        self.gap = gap
        self.labelBackground = labelBackground
        self.labelBorder = labelBorder
        self.cell = cell
    }

    /// The cell under the pointer, once it has been there long enough to
    /// be a question rather than a passing cursor.
    @State private var hoveredID: Item.ID?
    /// The cell the pointer is over right now, before the wait. It is what
    /// tells a hover that has already ended from one that is still going
    /// when the wait is up.
    @State private var hoverIntentID: Item.ID?

    /// How wide the whole row is.
    private func rowWidth(_ count: Int) -> CGFloat {
        count <= 0 ? 0 : CGFloat(count) * (iconWidth + gap) - gap
    }

    public var body: some View {
        GeometryReader { geo in
            let fits = rowWidth(items.count) <= geo.size.width
            Group {
                if fits {
                    // Centred, which is what it looks like almost always:
                    // a strip that scrolls when it does not need to reads
                    // as an accident.
                    marked(inset: max(0, (geo.size.width - rowWidth(items.count)) / 2))
                        // Spans the row so the inset above is what centres
                        // it. Deliberately NOT applied in the scrolling
                        // case below, where taking the whole viewport
                        // width is exactly what stops a scroll view from
                        // having anything to scroll.
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            marked(inset: 2)
                                .padding(.horizontal, 2)
                        }
                        .onChange(of: activeID) { _, id in
                            withAnimation(.railMove) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(height: geo.size.height)
        }
        .frame(height: 26)
    }

    /// The cells with the mark behind them. One layout for both the
    /// centred case and the scrolling one, so the mark cannot go missing
    /// in the case nobody looks at.
    @ViewBuilder
    private func marked(inset: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            IconRailMark(swipe: swipe, items: items, iconWidth: iconWidth, gap: gap, inset: inset)
            HStack(spacing: gap) {
                ForEach(items) { item in
                    cell(item)
                        .id(item.id)
                        .onHover { inside in
                            guard inside else {
                                if hoverIntentID == item.id { hoverIntentID = nil }
                                if hoveredID == item.id { hoveredID = nil }
                                return
                            }
                            hoverIntentID = item.id
                            // A short wait, so running the pointer along
                            // the row does not flash five names on the way
                            // past. Long enough to be a question, short
                            // enough that you have not already clicked one
                            // to find out.
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                guard hoverIntentID == item.id else { return }
                                withAnimation(.easeOut(duration: 0.09)) { hoveredID = item.id }
                            }
                        }
                }
            }
            .padding(.leading, inset)
        }
        // The name of the cell you are pointing at, drawn by us rather
        // than by the system: a macOS tooltip waits about a second, which
        // is longer than it takes to give up and click one to find out.
        // Anchored over the cell it names.
        .overlay(alignment: .topLeading) {
            if let hoveredID,
               let index = items.firstIndex(where: { $0.id == hoveredID }) {
                Text(items[index].name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(labelBackground)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 1)
                    )
                    .overlay(Capsule().stroke(labelBorder, lineWidth: 1))
                    .fixedSize()
                    // Centred over its cell, then pulled back inside the
                    // sidebar if the name is wider than the room to its
                    // right.
                    .alignmentGuide(.leading) { d in
                        d.width / 2 - iconWidth / 2
                    }
                    .offset(x: inset + CGFloat(index) * (iconWidth + gap), y: -26)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
}


/// The rounded mark behind the space you are in, and the one thing in
/// the row that moves with your fingers.
///
/// It slides in proportion to the swipe rather than jumping when the
/// swipe is judged, so the row answers "where am I going" while you are
/// still going there. It is its own view for one reason: it is the only
/// part of the strip cheap enough to redraw at gesture rate.
public struct IconRailMark<Item: IconRailItem>: View {
    @ObservedObject var swipe: RailSwipeModel
    let items: [Item]
    let iconWidth: CGFloat
    let gap: CGFloat
    let inset: CGFloat

    public init(swipe: RailSwipeModel, items: [Item], iconWidth: CGFloat, gap: CGFloat, inset: CGFloat) {
        self.swipe = swipe
        self.items = items
        self.iconWidth = iconWidth
        self.gap = gap
        self.inset = inset
    }

    public var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            mark
        }
    }

    @ViewBuilder
    private var mark: some View {
        let index = position
        let tint = items[min(max(Int(index.rounded()), 0), items.count - 1)].tint
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(tint.opacity(0.22))
            .frame(width: iconWidth, height: 24)
            .offset(x: inset + index * (iconWidth + gap))
            .allowsHitTesting(false)
    }

    /// Where the mark sits, in cells: a whole number at rest, a fraction
    /// of the way to the neighbour while the strip is being dragged.
    ///
    /// Clamped to the ends rather than wrapped. Going off one end and
    /// back on the other is right for the lists, which are a loop, and
    /// wrong for a row you can see all of at once, where it would read
    /// as the mark bolting across the whole strip.
    private var position: CGFloat {
        guard items.count > 1 else { return 0 }
        // The strip's own position, already measured in spaces: whole
        // number or fraction of the way between two. The mark has
        // nothing to work out for itself.
        return max(0, min(CGFloat(items.count - 1), swipe.position))
    }
}
