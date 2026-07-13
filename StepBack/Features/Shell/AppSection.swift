enum AppSection: Hashable {
    case routines
    case gallery
    case settings

    var title: String {
        switch self {
        case .routines: L10n.tabRoutines
        case .gallery: L10n.tabGallery
        case .settings: L10n.tabSettings
        }
    }

    var systemImage: String {
        switch self {
        case .routines: "play.rectangle.on.rectangle"
        case .gallery: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .routines: "tab.routines"
        case .gallery: "tab.gallery"
        case .settings: "tab.settings"
        }
    }
}
