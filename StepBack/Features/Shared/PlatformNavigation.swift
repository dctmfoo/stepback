import SwiftUI

extension View {
    @ViewBuilder
    func inlineNavigationTitleOnMobile() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    func activeListEditModeOnMobile() -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }

    @ViewBuilder
    func macSheetMinimumSize(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }

    @ViewBuilder
    func saveKeyboardShortcutOnMac() -> some View {
        #if os(macOS)
        keyboardShortcut("s", modifiers: .command)
        #else
        self
        #endif
    }
}
