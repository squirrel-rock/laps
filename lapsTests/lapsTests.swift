import XCTest
@testable import laps

final class FakeScheduler: ReminderScheduling {
    var plans: [[PlannedReminder]] = []
    var last: [PlannedReminder] { plans.last ?? [] }
    func apply(_ plan: [PlannedReminder]) { plans.append(plan) }
}

/// A clock the tests can move forward.
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
}

var testCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}()

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
    testCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

// MARK: - Lap math

final class LapMathTests: XCTestCase {
    func testThreeLapsMakeASet() {
        XCTAssertEqual(LapMath.sets(3), 1)
        XCTAssertEqual(LapMath.extraLaps(3), 0)
        XCTAssertEqual(LapMath.sets(4), 1)
        XCTAssertEqual(LapMath.extraLaps(4), 1)
        XCTAssertEqual(LapMath.sets(2), 0)
    }

    func testTenCreditsIsTheDailyGoal() {
        XCTAssertEqual(LapMath.dailyGoal, 10)
        XCTAssertEqual(LapMath.creditsToGoal(4), 6)
        XCTAssertEqual(LapMath.creditsToGoal(10), 0)
        XCTAssertEqual(LapMath.creditsToGoal(13), 0, "Never negative")
        XCTAssertEqual(LapMath.goalProgress(10), 1)
        XCTAssertEqual(LapMath.goalProgress(15), 1)
    }

    func testDescriptionsMatchSpecExample() {
        XCTAssertEqual(LapMath.setsDescription(4), "1 complete set + 1 lap")
        XCTAssertEqual(LapMath.statusLine(credits: 4), "6 laps to today's goal")
        XCTAssertEqual(LapMath.setsDescription(6), "2 complete sets")
        XCTAssertEqual(LapMath.setsDescription(2), "2 laps toward your first set")
        XCTAssertEqual(LapMath.setsDescription(0), "No laps yet today")
        XCTAssertEqual(LapMath.statusLine(credits: 9), "1 lap to today's goal")
        XCTAssertEqual(LapMath.setsShort(44), "14 sets + 2 laps")
    }

    func testMomentsCelebrateSetsGoalAndBeyond() {
        // No car walk: groups 3, 3, 3, 1, then gold 3 → the 10th lap is the goal, the 13th is lucky.
        XCTAssertEqual(LapMath.goalGroups(carWalks: 0), [3, 3, 3, 1])
        XCTAssertEqual(LapMath.moment(afterLap: 1, carWalks: 0), .lap)
        XCTAssertEqual(LapMath.moment(afterLap: 3, carWalks: 0), .set)
        XCTAssertEqual(LapMath.moment(afterLap: 9, carWalks: 0), .set)
        XCTAssertEqual(LapMath.moment(afterLap: 10, carWalks: 0), .goal)
        XCTAssertEqual(LapMath.message(afterLap: 10, carWalks: 0), "Ten today. Goal reached!")
        XCTAssertEqual(LapMath.moment(afterLap: 11, carWalks: 0), .bonusLap)
        XCTAssertEqual(LapMath.moment(afterLap: 12, carWalks: 0), .bonusLap)
        XCTAssertEqual(LapMath.moment(afterLap: 13, carWalks: 0), .lucky)
        XCTAssertEqual(LapMath.message(afterLap: 13, carWalks: 0), "Thirteen! A lucky number.")
        XCTAssertEqual(LapMath.moment(afterLap: 16, carWalks: 0), .bonusSet)
        // One car walk: groups 3, 3, 3 → the 9th lap is the goal, the 12th makes 13.
        XCTAssertEqual(LapMath.goalGroups(carWalks: 1), [3, 3, 3])
        XCTAssertEqual(LapMath.moment(afterLap: 9, carWalks: 1), .goal)
        XCTAssertEqual(LapMath.moment(afterLap: 10, carWalks: 1), .bonusLap)
        XCTAssertEqual(LapMath.moment(afterLap: 12, carWalks: 1), .lucky)
    }

    func testEachDotGroupClimbsCEG() {
        let notes = { (carWalks: Int) in (1...13).map { Sounds.note(LapMath.step(afterLap: $0, carWalks: carWalks).note) } }
        // No car walk: C E G, C E G, C E G, C (the 10th alone), then gold C E G.
        XCTAssertEqual(notes(0), [.lapC, .lapE, .lapG, .lapC, .lapE, .lapG, .lapC, .lapE, .lapG, .lapC, .lapC, .lapE, .lapG])
        // One car walk: three sets, then gold C E G.
        XCTAssertEqual(Array(notes(1).prefix(12)), [.lapC, .lapE, .lapG, .lapC, .lapE, .lapG, .lapC, .lapE, .lapG, .lapC, .lapE, .lapG])
    }

    func testAfterGoalWordingIsGentle() {
        XCTAssertEqual(LapMath.statusLine(credits: 10), "Goal reached! 3 gold laps make 13 — only if you feel up to it.")
        XCTAssertEqual(LapMath.statusLine(credits: 11), "2 more gold laps make 13 — only if you feel up to it.")
        XCTAssertEqual(LapMath.statusLine(credits: 12), "1 more gold lap makes 13 — only if you feel up to it.")
        XCTAssertEqual(LapMath.statusLine(credits: 13), "Thirteen! A lucky number. What a day!")
    }

    func testWalkingDescriptionAddsCarWalks() {
        XCTAssertEqual(LapMath.walkingDescription(laps: 6, carWalks: 0), "2 complete sets")
        XCTAssertEqual(LapMath.walkingDescription(laps: 6, carWalks: 1), "2 complete sets + 1 car walk")
        XCTAssertEqual(LapMath.walkingDescription(laps: 0, carWalks: 2), "2 car walks")
    }
}

// MARK: - Daily grouping

final class DayKeyTests: XCTestCase {
    let keys = DayKey(calendar: testCalendar)

    func testUsesLocalCalendarDate() {
        XCTAssertEqual(keys.key(for: date(2026, 11, 23, 23, 59)), "2026-11-23")
        XCTAssertEqual(keys.key(for: date(2026, 11, 24, 0, 1)), "2026-11-24")
    }

    func testRoundTrip() {
        let d = keys.date(for: "2026-03-08")!
        XCTAssertEqual(keys.key(for: d), "2026-03-08")
    }

    func testLastSevenDaysIncludesTodayOldestFirst() {
        let days = keys.lastDays(7, endingAt: date(2026, 11, 3, 8))
        XCTAssertEqual(days, ["2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31",
                              "2026-11-01", "2026-11-02", "2026-11-03"])
    }
}

// MARK: - Store, sessions and persistence

@MainActor
final class WalkStoreTests: XCTestCase {
    var url: URL!
    var clock: TestClock!
    var scheduler: FakeScheduler!

    override func setUp() async throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("walks.json")
        clock = TestClock(date(2026, 11, 23, 10))
        scheduler = FakeScheduler()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func makeStore() -> WalkStore {
        let c = clock!
        return WalkStore(fileURL: url, calendar: testCalendar, scheduler: scheduler, now: { c.now })
    }

    func testOneTapRecordsOneLapAndStartsASession() {
        let store = makeStore()
        XCTAssertEqual(store.recordLap(), 1)
        XCTAssertEqual(store.lapsToday, 1)
        XCTAssertEqual(store.active?.state, .walking)
        XCTAssertEqual(store.today.laps.first?.time, clock.now)
    }

    func testTwelveAndMoreLapsAreSupported() {
        let store = makeStore()
        for _ in 0..<14 { store.recordLap(); clock.advance(minutes: 2) }
        XCTAssertEqual(store.lapsToday, 14)
        XCTAssertEqual(LapMath.sets(store.lapsToday), 4)
    }

    func testUndoNeverGoesNegative() {
        let store = makeStore()
        store.recordLap()
        clock.advance(minutes: 3)
        store.recordLap()
        store.undoLastLap()
        XCTAssertEqual(store.lapsToday, 1)
        XCTAssertEqual(store.today.laps.first?.time, date(2026, 11, 23, 10), "Undo removes the latest lap")
        store.undoLastLap()
        store.undoLastLap()
        XCTAssertEqual(store.lapsToday, 0)
    }

    func testLapsPersistAcrossRestart() {
        do {
            let store = makeStore()
            store.recordLap(); store.recordLap(); store.recordLap(); store.recordLap()
            store.addEveryday("Walked to the car")
        }
        let reopened = makeStore()
        XCTAssertEqual(reopened.lapsToday, 4)
        XCTAssertEqual(reopened.today.everyday.map(\.note), ["Walked to the car"])
        XCTAssertEqual(reopened.active?.lapCount, 4, "An unfinished walk survives a restart too")
    }

    func testLapsAreCumulativeAcrossSessions() {
        let store = makeStore()
        store.recordLap(); store.recordLap()
        store.finishForNow()
        XCTAssertNil(store.active)
        clock.advance(minutes: 180)
        store.recordLap()
        XCTAssertEqual(store.lapsToday, 3)
        XCTAssertEqual(store.today.sessions.count, 1)
        XCTAssertEqual(store.today.sessions.first?.lapCount, 2)
    }

    func testCarWalksEarnCreditsButAreNotLaps() {
        let store = makeStore()
        store.addEveryday("Walked to the car")
        store.addEveryday("Walked to the mailbox")   // "Something else…": just a note
        XCTAssertNil(store.addEveryday("   "))
        store.recordLap()
        XCTAssertEqual(store.lapsToday, 1)
        XCTAssertEqual(store.carWalksToday, 1)
        XCTAssertEqual(store.walkingCreditsToday, 2)
        XCTAssertEqual(store.today.everyday.count, 2)
    }

    func testCarWalkCanBeUndone() {
        let store = makeStore()
        let entry = store.addEveryday(EverydayEntry.carWalk)!
        store.deleteEveryday(entry.id, on: store.todayKey)
        XCTAssertEqual(store.walkingCreditsToday, 0)
    }

    func testPreviousDaysAreKeptAndChartReadsSavedRecords() {
        let store = makeStore()
        for _ in 0..<12 { store.recordLap() }
        clock.advance(minutes: 60 * 24)          // next day
        store.recordLap()
        let week = store.lastSevenDays()
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.suffix(2).map(\.laps), [12, 1])
        XCTAssertEqual(week.prefix(5).map(\.laps), [0, 0, 0, 0, 0])
        XCTAssertEqual(store.record(for: "2026-11-23").lapCount, 12)
    }

    func testWeekBarsSplitIntoCarWalksLapsAndGold() {
        let d = WeekDay(key: "k", date: .now, laps: 11, carWalks: 1, standing: 0, lotion: false)
        XCTAssertEqual(d.walking, 12)
        XCTAssertTrue(d.walkingParts == (1, 9, 2))
        let noCar = WeekDay(key: "k", date: .now, laps: 7, carWalks: 0, standing: 0, lotion: false)
        XCTAssertTrue(noCar.walkingParts == (0, 7, 0))
    }

    func testWeekStandingBarsSplitIntoLotionVioletAndGold() {
        let d = WeekDay(key: "k", date: .now, laps: 0, carWalks: 0, standing: 12, lotion: true)
        XCTAssertTrue(d.standingParts(goal: 10) == (1, 9, 2))
        let noLotion = WeekDay(key: "k", date: .now, laps: 0, carWalks: 0, standing: 4, lotion: false)
        XCTAssertTrue(noLotion.standingParts(goal: 10) == (0, 4, 0))
    }

    func testWeekIncludesCarWalksAndStanding() {
        let store = makeStore()
        store.recordLap()
        store.addEveryday(EverydayEntry.carWalk)
        store.recordStoodUp()
        let today = store.lastSevenDays().last!
        XCTAssertEqual(today.walking, 2)
        XCTAssertEqual(today.standing, 1)
    }

    func testSessionLeftOpenOvernightIsClosedIntoItsOwnDay() {
        let store = makeStore()
        store.recordLap(); store.recordLap()
        clock.advance(minutes: 60 * 20)          // 6 AM next day
        store.closeStaleSession()
        XCTAssertNil(store.active)
        XCTAssertEqual(store.record(for: "2026-11-23").sessions.count, 1)
        XCTAssertEqual(store.lapsToday, 0)
    }

    func testCorrectingPastDay() {
        let store = makeStore()
        store.addLap(on: "2026-11-20")
        store.addLap(on: "2026-11-20")
        XCTAssertEqual(store.record(for: "2026-11-20").lapCount, 2)
        let first = store.record(for: "2026-11-20").laps[0].id
        store.deleteLap(first, on: "2026-11-20")
        XCTAssertEqual(store.record(for: "2026-11-20").lapCount, 1)
        XCTAssertEqual(store.lapsToday, 0)
    }

    func testUnreadableFileIsBackedUpNotLost() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = makeStore()
        XCTAssertNotNil(store.loadProblem)
        let files = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        XCTAssertTrue(files.contains { $0.contains("unreadable") })
    }

    func testStandUpPickThenDone() {
        let store = makeStore()
        let choices = store.standUpChoicesNow()
        XCTAssertEqual(choices.first, StandUps.spin)
        store.pickStandUp(choices[1])
        XCTAssertEqual(store.pendingStandUp?.choiceID, choices[1].id)
        XCTAssertEqual(store.standUpsDoneToday, 0)
        clock.advance(minutes: 3)
        XCTAssertEqual(store.completeStandUp(), 1)
        XCTAssertNil(store.pendingStandUp)
        XCTAssertEqual(store.lapsToday, 0, "Stand-ups never count as laps")
        XCTAssertEqual(makeStore().standUpsDoneToday, 1, "Saved")
    }

    func testPickingLotionAndFinishingMarksLotionDone() {
        let store = makeStore()
        store.pickStandUp(StandUps.lotion)
        store.completeStandUp()
        XCTAssertTrue(store.lotionDoneToday)
        XCTAssertFalse(store.standUpChoicesNow().contains(StandUps.lotion))
        XCTAssertFalse(scheduler.last.contains { $0.id.contains(store.todayKey) && $0.choiceIDs.contains("lotion") })
    }

    func testStandingCreditsCountQuickStandsIdeasAndLotionOnce() {
        let store = makeStore()
        store.recordStoodUp()
        store.recordStoodUp()   // honor system: no minimum gap between recordings
        XCTAssertEqual(store.standingCreditsToday, 2)
        store.pickStandUp(StandUps.lotion)
        store.completeStandUp()
        store.setLotionDone(true)   // ticking it again doesn't double-count
        XCTAssertEqual(store.standingCreditsToday, 3)
        store.pickStandUp(StandUps.spin)
        XCTAssertEqual(store.standingCreditsToday, 3, "Picked but not done yet")
        XCTAssertEqual(store.completeStandUp(), 4)
        store.setLotionDone(false)
        XCTAssertEqual(store.standingCreditsToday, 3)
        XCTAssertEqual(store.lapsToday, 0)
        XCTAssertEqual(store.walkingCreditsToday, 0, "Standing never counts toward walking")
    }

    func testQuickStandCanBeUndone() {
        let store = makeStore()
        let entry = store.recordStoodUp()
        store.deleteStandUp(entry.id, on: store.todayKey)
        XCTAssertEqual(store.standingCreditsToday, 0)
    }

    func testStandingGoalIsAdjustableAndSaved() {
        let store = makeStore()
        XCTAssertEqual(store.standingGoal, 10)
        store.setStandingGoal(12)
        XCTAssertEqual(makeStore().standingGoal, 12)
        store.setStandingGoal(99)
        XCTAssertEqual(store.standingGoal, 20, "Kept within range")
    }

    func testStandingPillGroupsAndWording() {
        XCTAssertEqual(StandingMath.goalGroups(goal: 10, lotionDone: false), [5, 5])
        XCTAssertEqual(StandingMath.goalGroups(goal: 10, lotionDone: true), [5, 4])
        XCTAssertEqual(StandingMath.statusLine(7, goal: 10), "3 more times up to today's goal")
        XCTAssertEqual(StandingMath.moment(after: 10, goal: 10), .goal)
        XCTAssertEqual(StandingMath.moment(after: 11, goal: 10), .bonus)
        XCTAssertEqual(StandingMath.statusLine(12, goal: 10), "2 gold bonuses. Wonderful!")
    }

    func testNewPickReplacesUnfinishedOne() {
        let store = makeStore()
        store.pickStandUp(StandUps.spin)
        store.pickStandUp(StandUps.exercises[0])
        XCTAssertEqual(store.today.standUps.count, 1)
        store.skipPendingStandUp()
        XCTAssertTrue(store.today.standUps.isEmpty)
    }

    func testNotificationChoicesDropLotionOnceDone() {
        let store = makeStore()
        store.setLotionDone(true)
        store.showStandUpPicker(choiceIDs: ["spin", "standups", "lotion"])
        XCTAssertFalse(store.standUpPrompt?.contains(StandUps.lotion) ?? true)
        XCTAssertEqual(store.standUpPrompt?.count, 3)
    }

    func testStandUpsHeldWhileWalking() {
        let store = makeStore()
        store.recordLap()
        XCTAssertEqual(store.standUpsQuietUntil, clock.now.addingTimeInterval(45 * 60))
        store.finishForNow()
        XCTAssertNil(store.standUpsQuietUntil)
    }

    func testFirstVersionSaveFileStillLoads() throws {
        let v1 = """
        {"version":1,"days":{"2026-11-23":{"day":"2026-11-23","laps":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","time":"2026-11-23T17:00:00Z"}],"everyday":[],"sessions":[]}},
         "settings":{"reminders":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","hour":7,"minute":30,"isOn":true}],"soundOn":false}}
        """
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(v1.utf8).write(to: url)
        let store = makeStore()
        XCTAssertNil(store.loadProblem)
        XCTAssertEqual(store.lapsToday, 1)
        XCTAssertFalse(store.settings.soundOn)
        XCTAssertEqual(store.settings.reminders.count, 1)
        XCTAssertTrue(store.settings.standUp.isOn)
        XCTAssertEqual(store.settings.standUp.startHour, 10)
        XCTAssertEqual(store.settings.standUp.startMinute, 30)
    }

    // MARK: Interruptions

    func testBathroomBreakSavesPausesAndSchedulesTenMinuteReminder() {
        let store = makeStore()
        store.recordLap(); store.recordLap(); store.recordLap(); store.recordLap()
        store.takeBathroomBreak()

        XCTAssertEqual(store.lapsToday, 4)
        XCTAssertEqual(store.active?.state, .onBreak)
        let breakReminder = scheduler.last.first { $0.kind == .bathroomBreak }
        XCTAssertEqual(breakReminder?.date, clock.now.addingTimeInterval(10 * 60))
        XCTAssertEqual(breakReminder?.title, "Ready to finish your walk?")
        XCTAssertEqual(makeStore().lapsToday, 4, "Laps saved to disk")

        clock.advance(minutes: 6)
        store.recordLap()      // resumes without starting over
        XCTAssertEqual(store.lapsToday, 5)
        XCTAssertEqual(store.active?.lapCount, 5)
        XCTAssertEqual(store.active?.breaks, 1)
        XCTAssertNil(scheduler.last.first { $0.kind == .bathroomBreak }, "Break reminder cancelled on resume")
    }

    func testFinishingCancelsBreakReminder() {
        let store = makeStore()
        store.recordLap()
        store.takeBathroomBreak()
        store.finishForNow()
        XCTAssertNil(store.active)
        XCTAssertNil(scheduler.last.first { $0.kind == .bathroomBreak })
        XCTAssertEqual(store.lapsToday, 1)
    }

    func testRemindMeLaterSchedulesThirtyMinutes() {
        let store = makeStore()
        store.remindMeLater()
        let later = scheduler.last.filter { $0.kind == .later }
        XCTAssertEqual(later.count, 1)
        XCTAssertEqual(later.first?.date, clock.now.addingTimeInterval(30 * 60))
        store.remindMeLater()
        XCTAssertEqual(scheduler.last.filter { $0.kind == .later }.count, 1, "No duplicates")
        store.recordLap()
        XCTAssertTrue(scheduler.last.filter { $0.kind == .later }.isEmpty, "Walking cancels it")
    }

    func testPauseForTodayClearsEverythingToday() {
        let store = makeStore()
        store.remindMeLater()
        store.setRemindersPausedToday(true)
        let todayKey = store.todayKey
        let walkReminders = scheduler.last.filter(\.isWalkReminder)
        XCTAssertFalse(walkReminders.contains { $0.kind != .daily })
        XCTAssertFalse(walkReminders.contains { $0.id.contains(todayKey) })
        XCTAssertTrue(walkReminders.contains { $0.id.contains("2026-11-24") }, "Tomorrow still reminds")
    }
}

// MARK: - Reminder planning

final class ReminderPlannerTests: XCTestCase {
    let now = date(2026, 11, 23, 10)     // 10 AM
    let keys = DayKey(calendar: testCalendar)

    func plan(_ settings: Settings = Settings(), laps: Int = 0, at: Date? = nil,
              lotionDone: Bool = false, quietUntil: Date? = nil) -> [PlannedReminder] {
        ReminderPlanner.plan(now: at ?? now, calendar: testCalendar, settings: settings, creditsToday: laps,
                             lotionDoneToday: lotionDone, standUpsQuietUntil: quietUntil)
    }

    func walks(_ p: [PlannedReminder], on key: String) -> [PlannedReminder] {
        p.filter { $0.kind == .daily && $0.id.contains(key) }
    }

    func standUps(_ p: [PlannedReminder], on key: String) -> [PlannedReminder] {
        p.filter { $0.kind == .standUp && $0.id.contains(key) }
    }

    var noStandUps: Settings {
        var s = Settings()
        s.standUp.isOn = false
        return s
    }

    func testSuggestedTimesSkipPastOnesToday() {
        let today = walks(plan(), on: "2026-11-23")
        XCTAssertEqual(today.map { testCalendar.component(.hour, from: $0.date) }, [13, 16])
        let tomorrow = walks(plan(), on: "2026-11-24")
        XCTAssertEqual(tomorrow.map { testCalendar.component(.hour, from: $0.date) }, [7, 13, 16])
        XCTAssertEqual(tomorrow.first.map { testCalendar.component(.minute, from: $0.date) }, 30)
    }

    func testIdsAreUniqueAndWithinSystemLimit() {
        var s = Settings()
        s.reminders = (6..<12).map { ReminderTime(hour: $0 + 8, minute: 0) }
        s.snoozeUntil = now.addingTimeInterval(1800)
        s.breakReminderAt = now.addingTimeInterval(600)
        let p = plan(s)
        XCTAssertLessThanOrEqual(p.count, ReminderPlanner.systemLimit)
        XCTAssertEqual(Set(p.map(\.id)).count, p.count)
    }

    func testCoversTwoWeeksWithThreeRemindersWhenStandUpsOff() {
        let days = Set(plan(noStandUps).map { keys.key(for: $0.date) })
        XCTAssertEqual(days.count, 14)
    }

    func testWalkRemindersCoverAWeekWhenStandUpsOn() {
        let days = Set(plan().filter { $0.kind == .daily }.map { keys.key(for: $0.date) })
        XCTAssertEqual(days.count, 7)
        XCTAssertLessThanOrEqual(plan().count, ReminderPlanner.systemLimit)
    }

    func testDisabledRemindersAreSkipped() {
        var s = Settings()
        s.reminders[1].isOn = false
        XCTAssertFalse(plan(s).contains { $0.kind == .daily && testCalendar.component(.hour, from: $0.date) == 13 })
    }

    func testNoRemindersLeavesOnlyOneOffs() {
        var s = noStandUps
        s.reminders = []
        s.snoozeUntil = now.addingTimeInterval(1800)
        XCTAssertEqual(plan(s).map(\.kind), [.later])
    }

    func testAfterGoalTodayRemindersBecomeGentleBonusInvitations() {
        XCTAssertFalse(walks(plan(laps: 9), on: "2026-11-23").contains { $0.title.contains("bonus") })
        let today = walks(plan(laps: 10), on: "2026-11-23")
        XCTAssertEqual(today.count, 2)
        XCTAssertTrue(today.allSatisfy { $0.title == "Feeling up for a bonus?" })
        let tomorrow = walks(plan(laps: 10), on: "2026-11-24")
        XCTAssertFalse(tomorrow.contains { $0.title.contains("bonus") })
    }

    func testAfterThirteenCreditsTodayIsQuiet() {
        XCTAssertFalse(walks(plan(laps: 12), on: "2026-11-23").isEmpty)
        XCTAssertTrue(walks(plan(laps: 13), on: "2026-11-23").isEmpty)
        XCTAssertFalse(walks(plan(laps: 13), on: "2026-11-24").isEmpty)
        XCTAssertFalse(standUps(plan(laps: 13), on: "2026-11-23").isEmpty, "Stand-ups carry on")
    }

    func testDailyReminderNearOneOffIsDropped() {
        var s = Settings()
        s.snoozeUntil = date(2026, 11, 23, 12, 50)     // 10 min before the 1 PM reminder
        let p = plan(s, at: date(2026, 11, 23, 12, 20))
        XCTAssertFalse(p.contains { $0.id == "walk.daily.2026-11-23.1300" })
        XCTAssertTrue(p.contains { $0.id == "walk.daily.2026-11-23.1600" })
    }

    func testExpiredOneOffsAreIgnored() {
        var s = Settings()
        s.snoozeUntil = now.addingTimeInterval(-60)
        s.breakReminderAt = now.addingTimeInterval(-60)
        XCTAssertTrue(plan(s).allSatisfy { $0.kind == .daily || $0.kind == .standUp })
    }

    func testPausedYesterdayDoesNotAffectToday() {
        var s = Settings()
        s.remindersPausedOn = "2026-11-22"
        XCTAssertEqual(walks(plan(s), on: "2026-11-23").count, 2)
    }

    func testDaylightSavingDayKeepsWallClockTimes() {
        // US clocks spring forward on 2026-03-08.
        let p = plan(at: date(2026, 3, 7, 20))
        let dst = walks(p, on: "2026-03-08")
        XCTAssertEqual(dst.map { testCalendar.component(.hour, from: $0.date) }, [7, 13, 16])
    }

    // MARK: Stand-ups

    func testStandUpsEveryHalfHourFromTenThirtyToEight() {
        var s = Settings()
        s.reminders = []
        let tomorrow = standUps(plan(s), on: "2026-11-24")
        XCTAssertEqual(tomorrow.count, 20)
        XCTAssertEqual(tomorrow.first.map { testCalendar.dateComponents([.hour, .minute], from: $0.date) },
                       DateComponents(hour: 10, minute: 30))
        XCTAssertEqual(tomorrow.last.map { testCalendar.dateComponents([.hour, .minute], from: $0.date) },
                       DateComponents(hour: 20, minute: 0))
    }

    func testStandUpSkippedWhenWalkReminderDue() {
        let p = plan()
        XCTAssertFalse(p.contains { $0.id == "standup.2026-11-24.1300" })
        XCTAssertFalse(p.contains { $0.id == "standup.2026-11-24.1600" })
        XCTAssertTrue(p.contains { $0.id == "standup.2026-11-24.1230" })
        XCTAssertTrue(p.contains { $0.id == "standup.2026-11-24.1330" })
    }

    func testStandUpsAlwaysOfferSpinAndLotionUntilDone() {
        let first = standUps(plan(), on: "2026-11-23").first!
        XCTAssertEqual(first.choiceIDs.count, 3)
        XCTAssertEqual(first.choiceIDs.first, "spin")
        XCTAssertEqual(first.choiceIDs.last, "lotion")
        XCTAssertTrue(first.body.hasPrefix("Pick one: a spin around the living room"))

        let afterLotion = standUps(plan(lotionDone: true), on: "2026-11-23")
        XCTAssertFalse(afterLotion.contains { $0.choiceIDs.contains("lotion") })
        let tomorrow = standUps(plan(lotionDone: true), on: "2026-11-24")
        XCTAssertTrue(tomorrow.allSatisfy { $0.choiceIDs.last == "lotion" }, "Lotion comes back the next day")
    }

    func testStandUpChoicesRotate() {
        let exercises = Set((0..<20).map { StandUps.choices(dayNumber: 100, slot: $0, lotionDone: true)[1].id })
        let fun = Set((0..<20).map { StandUps.choices(dayNumber: 100, slot: $0, lotionDone: true)[2].id })
        XCTAssertEqual(exercises.count, StandUps.exercises.count)
        XCTAssertEqual(fun.count, StandUps.fun.count)
        XCTAssertEqual(StandUps.choices(dayNumber: -3, slot: 0, lotionDone: true).count, 3)
    }

    func testStandUpsWaitDuringAWalk() {
        let p = plan(at: date(2026, 11, 23, 11, 0), quietUntil: date(2026, 11, 23, 11, 45))
        let today = standUps(p, on: "2026-11-23")
        XCTAssertEqual(today.first.map { testCalendar.dateComponents([.hour, .minute], from: $0.date) },
                       DateComponents(hour: 12, minute: 0))
    }

    func testStandUpsPausedTodayOnlyAffectsStandUps() {
        var s = Settings()
        s.standUp.pausedOn = "2026-11-23"
        XCTAssertTrue(standUps(plan(s), on: "2026-11-23").isEmpty)
        XCTAssertEqual(walks(plan(s), on: "2026-11-23").count, 2)
        XCTAssertFalse(standUps(plan(s), on: "2026-11-24").isEmpty)
    }

    func testStandUpsOffMeansNone() {
        XCTAssertFalse(plan(noStandUps).contains { $0.kind == .standUp })
    }
}
