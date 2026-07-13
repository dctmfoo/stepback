import SwiftUI

#if os(macOS)
struct MacSidebar: View {
    @Binding var selection: AppSection

    var body: some View {
        List(selection: $selection) {
            sectionRow(.routines)
            sectionRow(.gallery)
            sectionRow(.settings)
        }
        .navigationTitle(L10n.appName)
    }

    private func sectionRow(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
            .accessibilityIdentifier(section.accessibilityIdentifier)
    }
}
#endif
