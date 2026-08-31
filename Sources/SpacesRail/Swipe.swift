import SwiftUI

public extension Animation {
    /// The one curve every movement in a rail uses: the swipe settling, the
    /// strip sliding after a click or a shortcut, the mark catching up. Two
    /// curves for the same movement read as two mechanisms.
    static let railMove = Animation.spring(response: 0.34, dampingFraction: 0.9)
}

/// Where a strip of pages is, while a finger is moving it.
///
/// It is an object and not view state on purpose. A swipe reports a hundred
/// deltas a second, and if each one landed in the enclosing view's own state
/// that view would rebuild everything it draws a hundred times a second,
/// which is what a stuttering gesture is made of. Held here, the only thing
/// that re-renders per delta is the one small view that applies the offset.
@MainActor
public final class RailSwipeModel: ObservableObject {
    /// Where the strip is, measured in pages: a whole number when it is
    /// parked on one, a fraction of the way while a finger is moving it.
    ///
    /// In pages and not in points, which is the difference between a position
    /// and a position that was true when it was written. Held in points it
    /// has to be recalculated every time the container is resized, and the
    /// one place that does that can be missed: widen the container after a
    /// swipe and the strip stays parked at the old width's arithmetic,
    /// showing a slice of the page next door. Multiplied by the live width at
    /// the moment of drawing, there is nothing to keep in step.
    @Published public var position: CGFloat = 0

    /// The container's width, for turning finger movement into pages. The
    /// picture does not depend on it.
    public var width: CGFloat = 260

    public init(position: CGFloat = 0, width: CGFloat = 260) {
        self.position = position
        self.width = width
    }
}

/// Applies the swipe offset, and nothing else.
///
/// The content is a view value the caller built before the gesture started.
/// Re-running this body hands the same value back with a different offset, so
/// SwiftUI moves what it already has instead of rebuilding it.
public struct SwipingStrip<Content: View>: View {
    @ObservedObject private var model: RailSwipeModel
    /// The container's width right now, handed down from the layout rather
    /// than remembered, so a resize moves the strip by arithmetic instead of
    /// by someone noticing.
    private let width: CGFloat
    private let content: Content

    public init(model: RailSwipeModel, width: CGFloat, @ViewBuilder content: () -> Content) {
        self.model = model
        self.width = width
        self.content = content()
    }

    public var body: some View {
        content
            .offset(x: -model.position * width)
    }
}
