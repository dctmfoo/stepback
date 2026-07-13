import SwiftUI

struct AppShellView: View {
    var body: some View {
        #if os(macOS)
        MacAppShellView()
        #else
        TabAppShellView()
        #endif
    }
}
