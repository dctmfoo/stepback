#if os(macOS)
enum MacDetailRoute: Equatable {
    case routine(String)
    case workout(WorkoutItem)
}
#endif
