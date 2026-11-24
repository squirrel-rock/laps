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

    func testNineIsTheDailyGoal() {
        XCTAssertEqual(LapMath.dailyGoal, 9)
        XCTAssertEqual(LapMath.lapsToGoal(4), 5)
        XCTAssertEqual(LapMath.lapsToGoal(9), 0)
        XCTAssertEqual(LapMath.lapsToGoal(12), 0, "Never negative")
        XCTAssertEqual(LapMath.goalProgress(9), 1)
        XCTAssertEqual(LapMath.goalProgress(15), 1)
    }

    func testDescriptionsMatchSpecExample() {
        XCTAssertEqual(LapMath.setsDescription(4), "1 complete set + 1 lap")
        XCTAssertEqual(LapMath.statusLine(4), "5 laps to today's goal")
        XCTAssertEqual(LapMath.setsDescription(6), "2 complete sets")
        XCTAssertEqual(LapMath.setsDescription(2), "2 laps toward your first set")
        XCTAssertEqual(LapMath.setsDescription(0), "No laps yet today")
        XCTAssertEqual(LapMath.statusLine(8), "1 lap to today's goal")
        XCTAssertEqual(LapMath.setsShort(44), "14 sets + 2 laps")
    }

    func testMomentsCelebrateSetsGoalAndBeyond() {
        XCTAssertEqual(LapMath.moment(afterLap: 1), .lap)
        XCTAssertEqual(LapMath.moment(afterLap: 3), .set)
        XCTAssertEqual(LapMath.moment(afterLap: 9), .goal)
        XCTAssertEqual(LapMath.message(afterLap: 9), "Nine laps today. Goal reached!")
        XCTAssertEqual(LapMath.moment(afterLap: 10), .bonusLap)
        XCTAssertEqual(LapMath.moment(afterLap: 12), .fourSets)
        XCTAssertEqual(LapMath.message(afterLap: 12), "Four sets today. What a day!")
        XCTAssertEqual(LapMath.moment(afterLap: 15), .extraSet)
        XCTAssertEqual(LapMath.moment(afterLap: 16), .bonusLap)
    }

    func testAfterGoalWordingEncouragesFourthSetGently() {
        XCTAssertTrue(LapMath.statusLine(9).contains("only if you feel up to it"))
        XCTAssertTrue(LapMath.statusLine(10).contains("2 more laps"))
        XCTAssertTrue(LapMath.statusLine(11).contains("1 more lap "))
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

    func testEverydayWalkingDoesNotCountAsLaps() {
        let store = makeStore()
        store.addEveryday("Walked to the car")
        store.addEveryday("   ")
        XCTAssertEqual(store.lapsToday, 0)
        XCTAssertEqual(store.today.everyday.count, 1)
        XCTAssertEqual(store.lastSevenDays().last?.laps, 0)
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
        XCTAssertFalse(scheduler.last.contains { $0.kind != .daily })
        XCTAssertFalse(scheduler.last.contains { $0.id.contains(todayKey) })
        XCTAssertTrue(scheduler.last.contains { $0.id.contains("2026-11-24") }, "Tomorrow still reminds")
    }
}

// MARK: - Reminder planning

final class ReminderPlannerTests: XCTestCase {
    let now = date(2026, 11, 23, 10)     // 10 AM
    let keys = DayKey(calendar: testCalendar)

    func plan(_ settings: Settings = Settings(), laps: Int = 0, at: Date? = nil) -> [PlannedReminder] {
        ReminderPlanner.plan(now: at ?? now, calendar: testCalendar, settings: settings, lapsToday: laps)
    }

    func testSuggestedTimesSkipPastOnesToday() {
        let today = plan().filter { $0.id.contains("2026-11-23") }
        XCTAssertEqual(today.map { testCalendar.component(.hour, from: $0.date) }, [13, 16])
        let tomorrow = plan().filter { $0.id.contains("2026-11-24") }
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

    func testCoversTwoWeeksWithThreeReminders() {
        let days = Set(plan().map { keys.key(for: $0.date) })
        XCTAssertEqual(days.count, 14)
    }

    func testDisabledRemindersAreSkipped() {
        var s = Settings()
        s.reminders[1].isOn = false
        XCTAssertFalse(plan(s).contains { testCalendar.component(.hour, from: $0.date) == 13 })
    }

    func testNoRemindersLeavesOnlyOneOffs() {
        var s = Settings()
        s.reminders = []
        s.snoozeUntil = now.addingTimeInterval(1800)
        XCTAssertEqual(plan(s).map(\.kind), [.later])
    }

    func testAfterGoalTodayRemindersBecomeGentleBonusInvitations() {
        let today = plan(laps: 9).filter { $0.id.contains("2026-11-23") }
        XCTAssertEqual(today.count, 2)
        XCTAssertTrue(today.allSatisfy { $0.title == "Feeling up for a bonus set?" })
        let tomorrow = plan(laps: 9).filter { $0.id.contains("2026-11-24") }
        XCTAssertFalse(tomorrow.contains { $0.title.contains("bonus") })
    }

    func testAfterFourSetsTodayIsQuiet() {
        XCTAssertTrue(plan(laps: 12).filter { $0.id.contains("2026-11-23") }.isEmpty)
        XCTAssertFalse(plan(laps: 12).filter { $0.id.contains("2026-11-24") }.isEmpty)
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
        XCTAssertTrue(plan(s).allSatisfy { $0.kind == .daily })
    }

    func testPausedYesterdayDoesNotAffectToday() {
        var s = Settings()
        s.remindersPausedOn = "2026-11-22"
        XCTAssertEqual(plan(s).filter { $0.id.contains("2026-11-23") }.count, 2)
    }

    func testDaylightSavingDayKeepsWallClockTimes() {
        // US clocks spring forward on 2026-03-08.
        let p = plan(at: date(2026, 3, 7, 20))
        let dst = p.filter { $0.id.contains("2026-03-08") }
        XCTAssertEqual(dst.map { testCalendar.component(.hour, from: $0.date) }, [7, 13, 16])
    }
}
