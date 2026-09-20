import SwiftUI

struct StartView: View {
    let onStart: () -> Void

    var body: some View {
        PillButton(title: "Start", action: onStart)
            .keyboardShortcut(.defaultAction)
    }
}
