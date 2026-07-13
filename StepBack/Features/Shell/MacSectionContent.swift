import SwiftUI

#if os(macOS)
struct MacSectionContent: View {
    let section: AppSection
    let selectDetail: (MacDetailRoute) -> Void

    var body: some View {
        switch section {
        case .routines:
            RoutinesHomeView(selectRoutine: { selectDetail(.routine($0)) })
        case .gallery:
            GalleryView(
                selectWorkout: { selectDetail(.workout($0)) },
                selectRoutine: { selectDetail(.routine($0)) }
            )
        case .settings:
            SettingsView()
        }
    }
}
#endif
