import AppKit
import SpacesRail
import SwiftUI

/// A sidebar with five spaces, a list in each, and the rail underneath.
///
/// The lists are the point, not decoration. A scroll view under the gesture is
/// the case that makes this hard: AppKit hands `scrollWheel` to the deepest
/// view that handles it, so the list would take every swipe. Here you can
/// scroll a list vertically and swipe between spaces horizontally, in the same
/// square inch, which is the thing `RailSwipeCatcher` exists to do.
///
/// Built by hand rather than with `@main` and an `App`, because a SwiftUI app
/// launched by `swift run` is not a bundle: without setting the activation
/// policy it comes up behind whatever you ran it from, or not at all.
final class DemoDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SpacesRail"
        window.center()
        window.contentView = NSHostingView(rootView: DemoView())
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

struct Space: IconRailItem {
    let id = UUID()
    let name: String
    let tint: Color
    let glyph: String
    let items: [String]
}

struct DemoView: View {
    @StateObject private var swipe = RailSwipeModel()
    @State private var spaces: [Space] = [
        Space(name: "Work", tint: .blue, glyph: "briefcase.fill",
              items: ["Roadmap", "Q3 planning", "Hiring", "Invoices", "Standup notes",
                      "Design review", "Retro", "Budget", "Contracts", "Onboarding"]),
        Space(name: "Personal", tint: .purple, glyph: "house.fill",
              items: ["Groceries", "Flights", "Insurance", "Reading list", "Recipes",
                      "Gift ideas", "Car service", "Photos to print"]),
        Space(name: "Reading", tint: .orange, glyph: "book.fill",
              items: ["Papers", "Newsletters", "Saved threads", "Long reads",
                      "Book notes", "Quotes", "To finish"]),
        Space(name: "Music", tint: .pink, glyph: "music.note",
              items: ["Practice", "Setlists", "Gear", "Recordings", "Tabs", "Demos"]),
        Space(name: "Archive", tint: .green, glyph: "archivebox.fill",
              items: ["2024", "2023", "Old projects", "Receipts", "Screenshots"]),
    ]
    @State private var activeIndex = 0
    /// The icon a dragged one is currently over, for the mark that says where
    /// it would land.
    @State private var dropTargetID: UUID?

    private var active: Space { spaces[min(activeIndex, spaces.count - 1)] }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 260)
            Divider()
            content
        }
        .frame(minWidth: 700, minHeight: 420)
    }

    // MARK: - The sidebar

    private var sidebar: some View {
        GeometryReader { geo in
            let width = geo.size.width

            VStack(spacing: 0) {
                // Every list laid out side by side once, then moved as a
                // whole. Rebuilding them per delta is what a stuttering
                // gesture is made of.
                SwipingStrip(model: swipe, width: width) {
                    HStack(spacing: 0) {
                        ForEach(spaces) { space in
                            list(for: space).frame(width: width)
                        }
                    }
                }
                .frame(width: width, alignment: .leading)
                .clipped()

                Divider()

                IconRail(
                    swipe: swipe,
                    items: spaces,
                    activeID: active.id
                ) { space in
                    cell(for: space)
                }
                .frame(height: 40)
                .padding(.vertical, 6)
            }
            // The gesture. It reports every delta and then says when the
            // fingers are up, so the strip follows and settles rather than
            // jumping once a verdict is reached.
            .background(
                RailSwipeCatcher(
                    onDelta: { delta in
                        swipe.width = width
                        let limit = CGFloat(spaces.count - 1)
                        swipe.position = min(max(0, swipe.position - delta / width), limit)
                    },
                    onSettle: {
                        let landed = Int(swipe.position.rounded())
                        activeIndex = min(max(0, landed), spaces.count - 1)
                        withAnimation(.railMove) { swipe.position = CGFloat(activeIndex) }
                    }
                )
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    /// One space's list. A real scroll view, so the swipe has something to
    /// compete with.
    private func list(for space: Space) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: space.glyph).foregroundStyle(space.tint)
                Text(space.name).font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(space.items, id: \.self) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(space.tint.opacity(0.5))
                                .frame(width: 6, height: 6)
                            Text(item).font(.system(size: 12))
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    /// One cell in the rail. The rail lays it out and marks it; the click and
    /// the drag are the caller's, which is why reordering lives here and not
    /// in the package.
    @ViewBuilder
    private func cell(for space: Space) -> some View {
        let isActive = space.id == active.id
        Button {
            guard let index = spaces.firstIndex(where: { $0.id == space.id }) else { return }
            activeIndex = index
            withAnimation(.railMove) { swipe.position = CGFloat(index) }
        } label: {
            Image(systemName: space.glyph)
                .font(.system(size: 12))
                .frame(width: 26, height: 24)
                .foregroundStyle(isActive ? space.tint : Color.secondary)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(space.tint.opacity(dropTargetID == space.id ? 0.28 : 0))
        )
        .animation(.railMove, value: isActive)
        .animation(.easeOut(duration: 0.12), value: dropTargetID == space.id)
        .onDrag { NSItemProvider(object: space.id.uuidString as NSString) }
        .onDrop(of: [.text], isTargeted: Binding(
            get: { dropTargetID == space.id },
            set: { over in
                if over { dropTargetID = space.id }
                else if dropTargetID == space.id { dropTargetID = nil }
            }
        )) { providers in
            dropTargetID = nil
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { payload, _ in
                guard let text = payload as? String, let dragged = UUID(uuidString: text) else { return }
                Task { @MainActor in move(dragged, onto: space.id) }
            }
            return true
        }
    }

    /// A dropped icon, put where it was dropped, with the active one staying
    /// the space you were in rather than the position you left it at.
    @MainActor
    private func move(_ dragged: UUID, onto target: UUID) {
        guard dragged != target,
              let from = spaces.firstIndex(where: { $0.id == dragged }),
              let to = spaces.firstIndex(where: { $0.id == target }) else { return }
        let staying = active.id
        withAnimation(.railMove) {
            let space = spaces.remove(at: from)
            spaces.insert(space, at: to)
            if let index = spaces.firstIndex(where: { $0.id == staying }) {
                activeIndex = index
                swipe.position = CGFloat(index)
            }
        }
    }

    // MARK: - Something to the right of it

    private var content: some View {
        ZStack {
            active.tint.opacity(0.10)
            VStack(spacing: 12) {
                Image(systemName: active.glyph)
                    .font(.system(size: 46))
                    .foregroundStyle(active.tint)
                Text(active.name).font(.title2.weight(.semibold))
                VStack(spacing: 4) {
                    Text("Two fingers across the sidebar to move between spaces.")
                    Text("The lists scroll on their own; the swipe still gets through.")
                    Text("Drag an icon in the rail to put the spaces in another order.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .padding(30)
        }
    }
}

let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
