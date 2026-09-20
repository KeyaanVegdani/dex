import SwiftUI

/// The app's rounded pill button: yellow for the main action, grey for secondary ones.
struct PillButton: View {
    enum Style { case primary, secondary }

    let title: String
    var style: Style = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(style == .primary ? Theme.title : Theme.pillText)
                .padding(.horizontal, 64)
                .padding(.vertical, 20)
                .background(style == .primary ? Theme.yellow : Theme.pill, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
