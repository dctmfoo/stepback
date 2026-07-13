enum RoutineStepFormatting {
    static func summary(
        workSeconds: Int,
        sets: Int,
        setRestSeconds: Int,
        repGuidance: Int?,
        spoken: Bool = false
    ) -> String {
        let duration = spoken
            ? DisplayFormatters.spokenDuration(workSeconds)
            : DisplayFormatters.duration(workSeconds)
        let restDuration = spoken
            ? DisplayFormatters.spokenDuration(setRestSeconds)
            : DisplayFormatters.duration(setRestSeconds)

        var parts = [
            sets > 1
                ? L10n.setSummary(duration: duration, sets: sets)
                : duration
        ]
        if setRestSeconds > 0 {
            parts.append(L10n.setRest(restDuration))
        }
        if let repGuidance {
            parts.append(L10n.reps(repGuidance))
        }
        return parts.joined(separator: L10n.summarySeparator)
    }
}
