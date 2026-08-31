# Contributing

## What is most useful

Reports about input hardware. The event handling in `RailSwipeCatcher` is
tuned against an Apple trackpad and a Logitech wheel mouse, and those are the
only two devices it has ever run on. A Magic Mouse, a vertical mouse, a tablet
in relative mode or a trackpad with different momentum settings may well behave
differently, and I cannot find that out from here.

A useful report says which device, which macOS version, and what happened
instead of what you expected. Anything that involves the pointer sitting over a
scroll view is worth reporting even if it seems minor.

## Building

```
swift build
swift run SpacesRailDemo
```

There is no test suite, and adding one would not help much: everything here is
either a few lines of arithmetic or a gesture, and the gestures are what break.
`swift build` proves the types still line up and nothing else.

So changes to `SwipeCatcher.swift` have to be checked by hand. Run the demo and
work through these:

1. Two finger swipe across the sidebar moves the spaces, and stops at both ends
   rather than wrapping.
2. Vertical scroll inside a space's list scrolls the list, and does not move the
   spaces sideways.
3. A swipe that starts horizontal and drifts vertical keeps moving the spaces to
   the end of the gesture.
4. After a swipe, the list underneath does not scroll on its own. This is the
   momentum case and it is the one most likely to regress.
5. A mouse wheel tilted sideways moves the spaces, and they settle when it
   stops.
6. Dragging an icon in the rail reorders the spaces and leaves you in the space
   you were in.
7. Resize the window, then swipe. The strip lands on a whole space rather than
   between two.

Number 7 is the one people forget. It is what the position being measured in
pages rather than points exists for.

## Scope

The rail draws items and marks one of them. Everything a cell does when you
interact with it belongs to the caller. Pull requests that move click handling,
drag and drop, context menus, selection state or item mutation into the package
will be declined, however convenient they would be for one app: the boundary is
the reason this is separable from Nexion at all.

Additions that stay inside the boundary are a different matter. Vertical rails,
right to left layout, a configurable pitch: those are real gaps, and the reason
they are not here is that Nexion does not need them, not that they do not
belong.

## Nexion

This package is a dependency of [Nexion](https://nexion.one), not a copy that
was lifted out of it. That has one practical consequence: a change to the API
has to be worth making in an app you cannot see. It is why the surface is as
narrow as it is, and why I will push back on widening it.

## Style

Comments explain why, not what. `swipe.position` being measured in pages is one
line of code and a paragraph of comment, because the paragraph is the part that
stops someone rewriting it in points. If you fix a bug that took a while to
understand, leave the understanding behind.

Otherwise: standard Swift formatting, no third party dependencies, and nothing
that raises the deployment target without a reason worth the loss.
