import SwiftData

enum StepBackModelContainer {
    static let cloudKitContainerIdentifier = "iCloud.com.nags.stepback"

    static let schema = Schema([
        Routine.self,
        RoutineStep.self,
        CustomWorkout.self,
        RoutineSession.self,
        Plan.self,
        PlanSlot.self
    ])

    static func makeCloudKitBacked() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "StepBack",
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "StepBackTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
