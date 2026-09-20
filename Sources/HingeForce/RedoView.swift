import SwiftUI

/// Placeholder for whatever follows the lesson; for now it only lets you run the lesson again.
struct RedoView: View {
    let onRedo: () -> Void

    var body: some View {
        PillButton(title: "Redo lesson", style: .secondary, action: onRedo)
            .keyboardShortcut(.defaultAction)
    }
}
