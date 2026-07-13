import SwiftUI
import Observation

@MainActor
protocol PlayerLaunching {
    func play(_ routine: Routine)
    func play(_ routine: Routine, planContext: PlanLaunchContext)
}

struct NoopPlayerLauncher: PlayerLaunching {
    func play(_ routine: Routine) {}
    func play(_ routine: Routine, planContext: PlanLaunchContext) {}
}

struct PlayerLauncher: PlayerLaunching {
    let action: @MainActor (Routine, PlanLaunchContext?) -> Void

    init(action: @escaping @MainActor (Routine, PlanLaunchContext?) -> Void) {
        self.action = action
    }

    init(action: @escaping @MainActor (Routine) -> Void) {
        self.action = { routine, _ in action(routine) }
    }

    func play(_ routine: Routine) {
        action(routine, nil)
    }

    func play(_ routine: Routine, planContext: PlanLaunchContext) {
        action(routine, planContext)
    }
}

struct PlayerPresentation: Identifiable {
    let id = UUID()
    let routine: Routine
    let planContext: PlanLaunchContext?
}

@MainActor
@Observable
final class PlayerPresentationStore {
    var presentation: PlayerPresentation?
    let signposts: any PlayerSignposting

    init(signposts: any PlayerSignposting = SystemPlayerSignposter()) {
        self.signposts = signposts
    }

    func present(_ routine: Routine, planContext: PlanLaunchContext? = nil) {
        signposts.beginPlayToPreRoll()
        presentation = PlayerPresentation(routine: routine, planContext: planContext)
    }

    func dismiss() {
        signposts.endPlayToPreRoll()
        signposts.endSegment()
        presentation = nil
    }
}

extension EnvironmentValues {
    @Entry var playerLauncher: any PlayerLaunching = NoopPlayerLauncher()
}
