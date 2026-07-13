import StepBackCore
import SwiftUI

enum PlayerStageColors {
    static func accent(for kind: TimelineSegment.Kind?) -> Color {
        kind == .work ? Color("StageWork") : Color("StageRest")
    }
}
