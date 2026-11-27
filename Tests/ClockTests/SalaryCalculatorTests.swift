#if compiler(>=6.0)
import Foundation
import Testing
@testable import Clock

struct SalaryCalculatorTests {
    @Test func testPayBasisAndBreakBoundaries() throws {
        let calculator = SalaryCalculator(timeZone: TimeZone(secondsFromGMT: 0)!)
        var config = Config()
        config.enableLunchBreak = true
        config.monthlySalary = 6600
        config.dailySalary = 320
        config.hourlyRate = 40

        let start = try date("2024-05-06T09:30:00Z")
        let lunch = try date("2024-05-06T12:00:00Z")
        let resume = try date("2024-05-06T13:30:00Z")
        let end = try date("2024-05-06T18:30:00Z")

        #expect(calculator.snapshot(at: start.addingTimeInterval(-0.001), config: config).status == .beforeWork)
        for (basis, dailyPay) in [("monthly", 300.0), ("daily", 320.0), ("hourly", 300.0)] {
            config.salaryType = basis
            let working = calculator.snapshot(at: start, config: config)
            #expect(working.status == .working)
            #expect(working.nextTransitionMs == 9 * 3_600_000)

            let onBreak = calculator.snapshot(at: lunch, config: config)
            #expect(onBreak.status == .lunchBreak)
            #expect(onBreak.dailySalary == dailyPay)
            #expect(onBreak.workMsToday == 27_000_000)
            #expect(onBreak.elapsedWorkMs == 9_000_000)
            #expect(onBreak.nextTransitionMs == 5_400_000)
            #expect(abs(onBreak.earnedToday - dailyPay / 3) < 0.000_001)

            #expect(calculator.snapshot(at: resume, config: config).status == .working)
            #expect(calculator.snapshot(at: end, config: config).status == .afterWork)
        }

        config.lunchEnd = config.endTime
        #expect(calculator.snapshot(at: lunch, config: config).status == .invalidConfig)
    }

    @Test func testOvernightShiftBelongsToItsStartingWorkday() throws {
        let calculator = SalaryCalculator(timeZone: TimeZone(secondsFromGMT: 0)!)
        var config = Config()
        config.workdays = [5]
        config.startTime = "21:00"
        config.endTime = "6:00"
        config.enableLunchBreak = true
        config.lunchStart = "1:00"
        config.lunchEnd = "2:00"

        let onBreak = calculator.snapshot(at: try date("2024-05-04T01:00:00Z"), config: config)
        #expect(onBreak.status == .lunchBreak)
        #expect(!onBreak.isNightWork)
        #expect(onBreak.progress == 0.5)

        let completed = calculator.snapshot(at: try date("2024-05-04T12:00:00Z"), config: config)
        #expect(completed.status == .afterWork)
        #expect(completed.isNightWork)
        #expect(completed.earnedToday == completed.dailySalary)

        let restDay = calculator.snapshot(at: try date("2024-05-05T12:00:00Z"), config: config)
        #expect(restDay.status == .restDay)
        #expect(restDay.earnedToday == 0)
        #expect(restDay.earningsTimeline.isEmpty)
    }

    @Test func testEarningsTimelineStopsAtNowAndLevelsOffDuringLunch() throws {
        let calculator = SalaryCalculator(timeZone: TimeZone(secondsFromGMT: 0)!)
        var config = Config()
        config.enableLunchBreak = true

        let duringLunch = try date("2024-05-06T12:30:00Z")
        let onBreak = calculator.snapshot(at: duringLunch, config: config)
        let lunchTimes: [Double] = [0, 2.5 / 9, 3.0 / 9]
        #expect(onBreak.earningsTimeline.map(\.elapsed) == lunchTimes)
        #expect(onBreak.earningsTimeline.map(\.earned) == [0, onBreak.progress, onBreak.progress])

        let working = calculator.snapshot(at: try date("2024-05-06T15:30:00Z"), config: config)
        let afternoonTimes: [Double] = [0, 2.5 / 9, 4.0 / 9, 6.0 / 9]
        #expect(working.earningsTimeline.map(\.elapsed) == afternoonTimes)
        #expect(working.earningsTimeline.map(\.earned) == [0, onBreak.progress, onBreak.progress, working.progress])
    }

    @Test func testDaylightSavingGapAndRepeatedHour() throws {
        let calculator = SalaryCalculator(timeZone: try #require(TimeZone(identifier: "America/New_York")))
        var config = Config()
        config.workdays = [0]
        config.startTime = "02:30"
        config.endTime = "04:00"

        let spring = calculator.snapshot(at: try date("2024-03-10T07:45:00Z"), config: config)
        #expect(spring.status == .working)
        #expect(spring.workMsToday == 1_800_000)
        #expect(spring.elapsedWorkMs == 900_000)

        config.startTime = "01:30"
        config.endTime = "02:30"
        let fall = calculator.snapshot(at: try date("2024-11-03T06:30:00Z"), config: config)
        #expect(fall.status == .working)
        #expect(fall.workMsToday == 7_200_000)
        #expect(fall.elapsedWorkMs == 3_600_000)
    }

    private func date(_ timestamp: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: timestamp))
    }
}
#endif
