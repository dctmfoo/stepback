import Foundation

struct PlanLaunchContext: Codable, Equatable, Sendable {
    let planID: String
    let planNameSnapshot: String
    let weekIndex: Int?
    let slotIndex: Int?
    let slotID: String?

    init(
        planID: String,
        planNameSnapshot: String,
        weekIndex: Int? = nil,
        slotIndex: Int? = nil,
        slotID: String? = nil
    ) {
        self.planID = planID
        self.planNameSnapshot = planNameSnapshot
        self.weekIndex = weekIndex
        self.slotIndex = slotIndex
        self.slotID = slotID
    }
}
