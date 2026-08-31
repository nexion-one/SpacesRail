import AppKit
import SwiftUI


/// Two-finger horizontal scrolling over a view, reported as it
/// happens rather than as a verdict.
///
/// It hands back every delta and then says when the gesture is over, so
/// the strip of spaces can follow the fingers and settle afterwards.
/// Reporting only "you swiped left" would make the movement a thing that
/// starts after you let go, which is the difference between a page that
/// turns and a page you are turning.
///
/// It cannot be a SwiftUI gesture, and it cannot be a view that receives
/// the event either. A list underneath is often an `NSScrollView`, and AppKit hands
/// `scrollWheel` to the deepest view that handles it, so anything behind
/// the list never sees the event and anything in front of it would
/// swallow the clicks. What is left is a monitor at the window level,
/// filtered by asking whether the pointer is over this view.
public struct RailSwipeCatcher: NSViewRepresentable {
    /// Horizontal movement since the last report, in points.
    public let onDelta: (CGFloat) -> Void
    /// The fingers are up and the coasting has stopped.
    public let onSettle: () -> Void

    public init(onDelta: @escaping (CGFloat) -> Void, onSettle: @escaping () -> Void) {
        self.onDelta = onDelta
        self.onSettle = onSettle
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view, onDelta: onDelta, onSettle: onSettle)
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDelta = onDelta
        context.coordinator.onSettle = onSettle
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var onDelta: ((CGFloat) -> Void)?
        var onSettle: (() -> Void)?
        private weak var view: NSView?
        private var monitor: Any?
        private var settleWork: DispatchWorkItem?
        /// True from the moment a gesture is recognised as horizontal
        /// until it settles, so a wobble mid-gesture cannot hand the
        /// rest of it back to the list underneath.
        private var isTracking = false
        /// True between the fingers lifting and the coast dying, so the
        /// momentum that follows a gesture we handled is swallowed
        /// rather than handed to the list underneath.
        private var wasTracking = false

        func attach(
            to view: NSView,
            onDelta: @escaping (CGFloat) -> Void,
            onSettle: @escaping () -> Void
        ) {
            self.view = view
            self.onDelta = onDelta
            self.onSettle = onSettle
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) == true ? nil : event
            }
        }

        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            settleWork?.cancel()
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
            settleWork?.cancel()
        }

        /// Returns true when the event was consumed.
        private func handle(_ event: NSEvent) -> Bool {
            guard let view, let window = view.window, event.window === window else { return false }
            let point = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(point) else { return false }

            // Momentum is the coast after the fingers lift. It is
            // swallowed, not used: the decision was taken the moment the
            // fingers came up, and letting the coast move the strip as
            // well means the gesture appears to finish a second after it
            // did. This is where Zen's `MozSwipeGesture` fires rather
            // than `MozSwipeGestureEnd`, and for the same reason.
            if event.momentumPhase != [] {
                return isTracking || wasTracking
            }

            switch event.phase {
            case .began:
                isTracking = false
                wasTracking = false
            case .ended, .cancelled:
                guard isTracking else { return false }
                isTracking = false
                wasTracking = true
                settleWork?.cancel()
                onSettle?()
                return true
            default:
                break
            }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            // A vertical scroll that wobbles sideways is still a vertical
            // scroll: leave it to the list. Judged once, at the start;
            // after that the gesture is ours until it ends, because a
            // swipe that grows a vertical component halfway through
            // should not drop the strip where it stands.
            if !isTracking {
                guard abs(dx) > abs(dy) * 1.5, abs(dx) > 0.5 else { return false }
                isTracking = true
                wasTracking = false
            }

            onDelta?(dx)
            // Only a mouse wheel needs this: it has no phases at all, so
            // a pause is the only thing that says the gesture is over.
            if event.phase == [] { scheduleSettle() }
            return true
        }

        /// A mouse wheel never says it has finished, so quiet does.
        private func scheduleSettle() {
            settleWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isTracking = false
                self.wasTracking = false
                self.onSettle?()
            }
            settleWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }
    }
}
