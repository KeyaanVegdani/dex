import AppKit
import SwiftUI

/// Gives a button's label a background that turns to the hover colour while the pointer is over it. The colour eases
/// over rather than snapping.
///
/// The background is drawn here, from the hover state, rather than laid over the label, so it can't cover the text
/// or come out a different grey to the one asked for.
struct HoverSurface<S: Shape>: ViewModifier {
    let shape: S
    /// The background when the pointer isn't over it. Use `.clear` for a button with no background of its own.
    let rest: Color
    let hover: Color
    @State private var hovering: Bool

    /// `startsHovering` exists so tests and previews can show the hovered look without a pointer.
    init(shape: S, rest: Color, hover: Color, startsHovering: Bool = false) {
        self.shape = shape
        self.rest = rest
        self.hover = hover
        _hovering = State(initialValue: startsHovering)
    }

    func body(content: Content) -> some View {
        content
            .background(hovering ? hover : rest, in: shape)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .contentShape(shape)
            .onHover { hovering = $0 }
    }
}

extension View {
    /// A background for a button label that darkens to `#E3E3E3` (or `hover`) when the pointer is over it.
    func hoverSurface<S: Shape>(_ shape: S, rest: Color = Theme.pill, hover: Color = Theme.pillHover) -> some View {
        modifier(HoverSurface(shape: shape, rest: rest, hover: hover))
    }
}

/// Shows the pointing-hand cursor while the pointer is over a view, to say it can be clicked.
///
/// On macOS 15 and later this uses the system's pointer style, which looks after itself. Before that the cursor is
/// pushed and popped by hand, and popped again if the view goes away while it is hovered, so the hand can't be left
/// stuck on.
struct PointerCursor: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.link)
        } else {
            content
                .onHover { hovering in
                    if hovering, !pushed {
                        NSCursor.pointingHand.push()
                        pushed = true
                    } else if !hovering, pushed {
                        NSCursor.pop()
                        pushed = false
                    }
                }
                .onDisappear {
                    if pushed {
                        NSCursor.pop()
                        pushed = false
                    }
                }
        }
    }
}
