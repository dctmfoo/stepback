import Foundation

struct InFlightSessionMarker: Codable, Equatable, Sendable {
    let routineID: String
    let routineNameSnapshot: String
    let startedAt: Date
    let totalStepCount: Int
    let activeSeconds: Int
    let completedStepCount: Int
    let updatedAt: Date
    let planContext: PlanLaunchContext?

    init(
        routineID: String,
        routineNameSnapshot: String,
        startedAt: Date,
        totalStepCount: Int,
        activeSeconds: Int,
        completedStepCount: Int,
        updatedAt: Date,
        planContext: PlanLaunchContext? = nil
    ) {
        self.routineID = routineID
        self.routineNameSnapshot = routineNameSnapshot
        self.startedAt = startedAt
        self.totalStepCount = totalStepCount
        self.activeSeconds = activeSeconds
        self.completedStepCount = completedStepCount
        self.updatedAt = updatedAt
        self.planContext = planContext
    }

    private enum CodingKeys: String, CodingKey {
        case routineID, routineNameSnapshot, startedAt, totalStepCount
        case activeSeconds, completedStepCount, updatedAt, planContext
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        routineID = try values.decode(String.self, forKey: .routineID)
        routineNameSnapshot = try values.decode(String.self, forKey: .routineNameSnapshot)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        totalStepCount = try values.decode(Int.self, forKey: .totalStepCount)
        activeSeconds = try values.decode(Int.self, forKey: .activeSeconds)
        completedStepCount = try values.decode(Int.self, forKey: .completedStepCount)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        planContext = try values.decodeIfPresent(PlanLaunchContext.self, forKey: .planContext)
    }
}
