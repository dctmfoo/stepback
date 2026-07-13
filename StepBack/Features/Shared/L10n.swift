import Foundation

enum L10n {
    static var appName: String { String(localized: "app.name") }
    static var tabRoutines: String { String(localized: "tab.routines") }
    static var tabGallery: String { String(localized: "tab.gallery") }
    static var tabSettings: String { String(localized: "tab.settings") }
    static var newRoutine: String { String(localized: "home.new-routine") }
    static var noRoutinesTitle: String { String(localized: "home.empty.title") }
    static var noRoutinesMessage: String { String(localized: "home.empty.message") }
    static var restoreStarters: String { String(localized: "home.empty.restore") }
    static var notPlayedYet: String { String(localized: "routine.stats.never") }
    static var play: String { String(localized: "routine.play") }
    static var editRoutine: String { String(localized: "routine.edit") }
    static var duplicate: String { String(localized: "routine.duplicate") }
    static var deleteRoutine: String { String(localized: "routine.delete") }
    static var noStepsTitle: String { String(localized: "routine.empty.title") }
    static var noStepsMessage: String { String(localized: "routine.empty.message") }
    static var addYourOwn: String { String(localized: "gallery.add-your-own") }
    static var yours: String { String(localized: "gallery.yours") }
    static var addToRoutine: String { String(localized: "workout.add-to-routine") }
    static var editWorkout: String { String(localized: "workout.edit") }
    static var deleteWorkout: String { String(localized: "workout.delete") }
    static var newWorkoutTitle: String { String(localized: "custom.new.title") }
    static var editWorkoutTitle: String { String(localized: "custom.edit.title") }
    static var name: String { String(localized: "custom.name") }
    static var category: String { String(localized: "custom.category") }
    static var notes: String { String(localized: "custom.notes") }
    static var notesPlaceholder: String { String(localized: "custom.notes.placeholder") }
    static var save: String { String(localized: "common.save") }
    static var cancel: String { String(localized: "common.cancel") }
    static var dismiss: String { String(localized: "common.dismiss") }
    static var errorTitle: String { String(localized: "common.error.title") }
    static var errorMessage: String { String(localized: "common.error.message") }
    static var privacy: String { String(localized: "settings.privacy") }
    static var selectedRoutinePrompt: String { String(localized: "shell.select-routine") }
    static var selectedWorkoutPrompt: String { String(localized: "shell.select-workout") }
    static var today: String { String(localized: "date.today") }

    static func format(_ key: String, _ argument: CVarArg) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            argument
        )
    }

    static func format(_ key: String, _ first: CVarArg, _ second: CVarArg) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            first,
            second
        )
    }

    static func format(_ key: String, _ first: CVarArg, _ second: CVarArg, _ third: CVarArg) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            first,
            second,
            third
        )
    }

    private static func pluralFormat(
        _ key: String,
        count: Int,
        one: String,
        other: String
    ) -> String {
        guard UserDefaults.standard.bool(forKey: "NSDoubleLocalizedStrings") else {
            return format(key, count)
        }

        // Foundation's double-localization diagnostic duplicates the
        // NSStringLocalizedFormatKey token inside compiled plural catalogs.
        // Format the English diagnostic value first so pseudolocalization can
        // still exercise the doubled layout without exposing format tokens.
        let template = count == 1 ? one : other
        let value = String(format: template, locale: Locale(identifier: "en"), count)
        return "\(value) \(value)"
    }

    static func workoutCount(_ count: Int) -> String {
        pluralFormat(
            "routine.workout-count",
            count: count,
            one: "%lld workout",
            other: "%lld workouts"
        )
    }

    static func lastDone(_ relativeDate: String, timesCompleted: Int) -> String {
        if UserDefaults.standard.bool(forKey: "NSDoubleLocalizedStrings") {
            let value = String(
                format: "Last done %@ · %lld×",
                locale: Locale(identifier: "en"),
                relativeDate,
                timesCompleted
            )
            return "\(value) \(value)"
        }

        return format("routine.stats.last-done", relativeDate, timesCompleted)
    }

    static func playRoutine(_ name: String) -> String {
        format("ax.play-routine", name)
    }

    static func duplicateName(_ name: String) -> String {
        format("routine.duplicate.name", name)
    }

    static func defaultRoutineName(_ number: Int) -> String {
        format("routine.default-name", number)
    }

    static func deleteRoutineTitle(_ name: String) -> String {
        format("routine.delete.confirm.title", name)
    }

    static var deleteRoutineMessage: String {
        String(localized: "routine.delete.confirm.message")
    }

    static func rest(_ duration: String) -> String {
        format("routine.rest", duration)
    }

    static func accessibilityRest(_ duration: String) -> String {
        format("ax.rest", duration)
    }

    static func setSummary(duration: String, sets: Int) -> String {
        format("step.summary.sets", duration, sets)
    }

    static func setRest(_ duration: String) -> String {
        format("step.summary.set-rest", duration)
    }

    static func reps(_ count: Int) -> String {
        pluralFormat(
            "step.summary.reps",
            count: count,
            one: "~%lld rep",
            other: "~%lld reps"
        )
    }

    static var summarySeparator: String { String(localized: "common.summary-separator") }

    static func searchPrompt(_ count: Int) -> String {
        pluralFormat(
            "gallery.search.prompt",
            count: count,
            one: "Search %lld workout",
            other: "Search %lld workouts"
        )
    }

    static func categoryCount(_ count: Int) -> String {
        pluralFormat(
            "gallery.category.count",
            count: count,
            one: "%lld workout",
            other: "%lld workouts"
        )
    }

    static func categoryYours(_ count: Int) -> String {
        pluralFormat(
            "gallery.category.yours",
            count: count,
            one: "%lld yours",
            other: "%lld yours"
        )
    }

    static func appearsIn(_ count: Int) -> String {
        pluralFormat(
            "workout.appears-in",
            count: count,
            one: "Appears in %lld routine",
            other: "Appears in %lld routines"
        )
    }

    static func appearsInMore(_ count: Int) -> String {
        pluralFormat(
            "workout.appears-in.more",
            count: count,
            one: "and %lld more",
            other: "and %lld more"
        )
    }

    static var newRoutineFromWorkout: String { String(localized: "addto.new-routine") }
    static var addToRoutineTitle: String { String(localized: "addto.title") }
    static var builderTitleNew: String { String(localized: "builder.title.new") }
    static var builderTitleEdit: String { String(localized: "builder.title.edit") }
    static var builderNameLabel: String { String(localized: "builder.name.label") }
    static var builderAddWorkouts: String { String(localized: "builder.add-workouts") }
    static var builderTotal: String { String(localized: "builder.total") }
    static var builderEmptyTitle: String { String(localized: "builder.empty.title") }
    static var builderEmptyMessage: String { String(localized: "builder.empty.message") }
    static var builderStepWork: String { String(localized: "builder.step.work") }
    static var builderStepSets: String { String(localized: "builder.step.sets") }
    static var builderStepSetRest: String { String(localized: "builder.step.set-rest") }
    static var builderStepRepGuidance: String { String(localized: "builder.step.rep-guidance") }
    static var builderStepRestAfter: String { String(localized: "builder.step.rest-after") }
    static var builderStepOff: String { String(localized: "builder.step.off") }
    static var builderStepRestAfterFootnote: String { String(localized: "builder.step.rest-after.footnote") }
    static var builderStepActions: String { String(localized: "builder.step.actions") }
    static var builderStepMoveUp: String { String(localized: "builder.step.move-up") }
    static var builderStepMoveDown: String { String(localized: "builder.step.move-down") }
    static var builderStepDelete: String { String(localized: "builder.step.delete") }
    static var builderStepExpandHint: String { String(localized: "builder.step.expand-hint") }
    static var builderStepCollapseHint: String { String(localized: "builder.step.collapse-hint") }
    static var builderDiscardTitle: String { String(localized: "builder.discard.title") }
    static var builderDiscardConfirm: String { String(localized: "builder.discard.confirm") }
    static var builderDiscardKeep: String { String(localized: "builder.discard.keep") }
    static var builderPickerSearch: String { String(localized: "builder.picker.search") }
    static var builderPickerAll: String { String(localized: "builder.picker.all") }
    static var builderPickerSelected: String { String(localized: "builder.picker.selected") }

    static func builderPickerAddCount(_ count: Int) -> String {
        pluralFormat(
            "builder.picker.add-count",
            count: count,
            one: "Add %lld Workout",
            other: "Add %lld Workouts"
        )
    }

    static func builderStepAccessibility(_ name: String, _ summary: String) -> String {
        format("builder.step.accessibility", name, summary)
    }

    static func deleteWorkoutTitle(_ name: String) -> String {
        format("workout.delete.confirm.title", name)
    }

    static var deleteWorkoutMessage: String {
        String(localized: "workout.delete.confirm.message")
    }

    static func streak(_ count: Int) -> String {
        pluralFormat(
            "home.streak",
            count: count,
            one: "%lld-day streak",
            other: "%lld-day streak"
        )
    }

    static func bestStreak(_ count: Int) -> String {
        format("home.streak.best", count)
    }

    static func weeklyMinutes(_ count: Int) -> String {
        pluralFormat(
            "home.week.minutes",
            count: count,
            one: "%lld min this week",
            other: "%lld min this week"
        )
    }

    static func weeklySessions(_ count: Int) -> String {
        pluralFormat(
            "home.week.sessions",
            count: count,
            one: "%lld session",
            other: "%lld sessions"
        )
    }

    static func version(version: String, build: String) -> String {
        format("settings.version", version, build)
    }

    static var playerWindowTitle: String { String(localized: "player.window.title") }
    static var playerUnavailable: String { String(localized: "player.unavailable") }
    static var playerWakeReason: String { String(localized: "player.wake.reason") }
    static var playerKickerWork: String { String(localized: "player.kicker.work") }
    static var playerKickerRest: String { String(localized: "player.kicker.rest") }
    static var playerKickerGetReady: String { String(localized: "player.kicker.get-ready") }
    static var playerPause: String { String(localized: "player.pause") }
    static var playerResume: String { String(localized: "player.resume") }
    static var playerSkip: String { String(localized: "player.skip") }
    static var playerBack: String { String(localized: "player.back") }
    static var playerEnd: String { String(localized: "player.end") }
    static var playerEndConfirmTitle: String { String(localized: "player.end.confirm.title") }
    static var playerEndConfirm: String { String(localized: "player.end.confirm") }
    static var playerEndKeep: String { String(localized: "player.end.keep") }
    static var playerCompleteTitle: String { String(localized: "player.complete.title") }
    static var playerCompleteDone: String { String(localized: "player.complete.done") }
    static var playerCompleteGoAgain: String { String(localized: "player.complete.go-again") }
    static var playerTimeRemaining: String { String(localized: "player.time-remaining") }
    static var playerProgress: String { String(localized: "player.progress") }
    static var kickerSeparator: String { String(localized: "player.kicker.separator") }
    static var speechSeparator: String { String(localized: "speech.separator") }
    static var settingsSectionAudio: String { String(localized: "settings.section.audio") }
    static var settingsVoice: String { String(localized: "settings.voice") }
    static var settingsVoiceDetail: String { String(localized: "settings.voice.detail") }
    static var settingsTones: String { String(localized: "settings.tones") }
    static var settingsTonesDetail: String { String(localized: "settings.tones.detail") }
    static var settingsSectionPlayer: String { String(localized: "settings.section.player") }
    static var settingsGetReady: String { String(localized: "settings.get-ready") }
    static var settingsGetReadyDetail: String { String(localized: "settings.get-ready.detail") }
    static var settingsSectionICloud: String { String(localized: "settings.section.icloud") }
    static var settingsSync: String { String(localized: "settings.sync") }
    static var settingsSyncChecking: String { String(localized: "settings.sync.checking") }
    static var settingsSyncUpToDate: String { String(localized: "settings.sync.up-to-date") }
    static var settingsSyncUnavailable: String { String(localized: "settings.sync.unavailable") }
    static var settingsAgentBridgeTitle: String { String(localized: "settings.agentBridge.title") }
    static var settingsAgentBridgeToggle: String { String(localized: "settings.agentBridge.toggle") }
    static var settingsAgentBridgeFooter: String { String(localized: "settings.agentBridge.footer") }
    static var settingsAgentBridgeReveal: String { String(localized: "settings.agentBridge.reveal") }
    static var agentProvenance: String { String(localized: "detail.provenance.agent") }
    static var welcomeTitle: String { String(localized: "welcome.title") }
    static var welcomeTagline: String { String(localized: "welcome.tagline") }
    static var welcomeCompose: String { String(localized: "welcome.compose") }
    static var welcomeComposeDetail: String { String(localized: "welcome.compose.detail") }
    static var welcomePlay: String { String(localized: "welcome.play") }
    static var welcomePlayDetail: String { String(localized: "welcome.play.detail") }
    static var welcomeFollow: String { String(localized: "welcome.follow") }
    static var welcomeFollowDetail: String { String(localized: "welcome.follow.detail") }
    static var welcomePrivacy: String { String(localized: "welcome.privacy") }
    static var welcomeGetStarted: String { String(localized: "welcome.get-started") }
    static var playerCompleteStreakLabel: String { String(localized: "player.complete.streak.label") }
    static var playerCompleteTimesLabel: String { String(localized: "player.complete.times.label") }
    static var plansSectionTitle: String { String(localized: "plans.section.title") }
    static var plansNew: String { String(localized: "plans.new") }
    static var plansEdit: String { String(localized: "plans.edit") }
    static var plansEditorDuplicatePlan: String { String(localized: "plans.editor.duplicatePlan") }
    static var plansEditorAddRoutine: String { String(localized: "plans.editor.addRoutine") }
    static var plansRoutineRemoved: String { String(localized: "plans.slot.routineRemoved") }
    static var plansDeleteConfirmTitle: String { String(localized: "plans.delete.confirm.title") }
    static var plansDelete: String { String(localized: "plans.delete") }
    static var plansReplaceRoutine: String { String(localized: "plans.editor.replaceRoutine") }
    static var plansTodayKicker: String { String(localized: "plans.today.kicker") }
    static var plansTodayDoneTitle: String { String(localized: "plans.today.done.title") }
    static var plansTodayRestTitle: String { String(localized: "plans.today.rest.title") }
    static var plansMyWeekTitle: String { String(localized: "plans.myWeek.title") }
    static var plansMyWeekSet: String { String(localized: "plans.myWeek.set") }
    static var plansMyWeekChoose: String { String(localized: "plans.myWeek.choose") }
    static var plansNudgeTitle: String { String(localized: "plans.nudge.title") }
    static var plansNudgeMessage: String { String(localized: "plans.nudge.message") }
    static var plansDayRest: String { String(localized: "plans.day.rest") }
    static var plansDayDoneAccessibility: String {
        String(localized: "plans.day.done.accessibility")
    }
    static func plansDayRoutineAccessibility(_ day: String, _ routine: String) -> String {
        String(localized: "plans.day.routine.accessibility \(day) \(routine)")
    }
    static var plansTodayRepair: String { String(localized: "plans.today.repair") }

    static func plansDefaultName(_ number: Int) -> String {
        format("plans.defaultName", number)
    }

    static func plansMigrationWeekName(_ name: String, _ week: Int) -> String {
        format("plans.migration.week-name", name, week)
    }

    static func plansTodayNext(_ weekday: String, _ routine: String) -> String {
        format("plans.today.next", weekday, routine)
    }

    static func plansTodayMultiCount(_ completed: Int, _ total: Int) -> String {
        format("plans.today.multi.count", completed, total)
    }

    static func plansTodayStripAccessibility(_ completed: Int, _ total: Int) -> String {
        format("plans.today.strip.accessibility", completed, total)
    }

    static func plansMyWeekRow(_ name: String) -> String { format("plans.myWeek.row", name) }

    static func plansPickerSummary(_ days: Int, _ routines: String) -> String {
        format("plans.picker.summary", days, routines)
    }

    static func playerSetIndicator(_ setIndex: Int, setCount: Int) -> String {
        format("player.set-indicator", setIndex, setCount)
    }

    static func playerWorkoutIndicator(_ index: Int, count: Int) -> String {
        format("player.workout-indicator", index, count)
    }

    static func playerNext(_ name: String) -> String { format("player.next", name) }
    static func playerFirst(_ name: String) -> String { format("player.first", name) }

    static func playerCompletedWorkouts(_ count: Int) -> String {
        pluralFormat(
            "player.complete.workouts",
            count: count,
            one: "%lld workout completed",
            other: "%lld workouts completed"
        )
    }

    static func playerCompleteStreak(_ count: Int) -> String {
        pluralFormat(
            "player.complete.streak",
            count: count,
            one: "%lld day",
            other: "%lld days"
        )
    }

    static func playerCompleteTimes(_ count: Int) -> String {
        format("player.complete.times", count)
    }

    static func playerPartialMessage(_ duration: String) -> String {
        format("player.partial.message", duration)
    }

    static func playerProgressValue(_ elapsed: String, remaining: String) -> String {
        format("player.progress.value", elapsed, remaining)
    }

    static func speechWork(_ name: String) -> String { format("speech.work", name) }
    static func speechWorkSet(_ name: String, setIndex: Int, setCount: Int) -> String {
        format("speech.work-set", name, setIndex, setCount)
    }
    static func speechReps(_ count: Int) -> String { format("speech.reps", count) }
    static func speechRest(_ name: String) -> String { format("speech.rest", name) }
    static func speechSetRest(_ nextSet: Int, setCount: Int) -> String {
        format("speech.set-rest", nextSet, setCount)
    }
    static func speechGetReady(_ name: String) -> String { format("speech.get-ready", name) }
    static func speechComplete(_ duration: String) -> String { format("speech.complete", duration) }
}
