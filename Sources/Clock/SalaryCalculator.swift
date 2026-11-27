// SPDX-FileCopyrightText: 2026 Mr.Baoboer
// SPDX-License-Identifier: AGPL-3.0-only
//
// Additional terms: see /legal/ADDITIONAL_TERMS.md

import Foundation

struct Config: Codable {
    var salaryType = "monthly", monthlySalary = 10000.0, dailySalary = 360.0, hourlyRate = 45.0
    var workDaysPerMonth = 22.0, workdays = [1,2,3,4,5]
    var startTime = "09:30", endTime = "18:30", lunchStart = "12:00", lunchEnd = "13:30"
    var enableLunchBreak = false
}

enum SalaryStatus: String {
    case invalidConfig = "invalid-config"
    case restDay = "rest-day"
    case beforeWork = "before-work"
    case working
    case lunchBreak = "lunch-break"
    case afterWork = "after-work"
}

struct EarningsPoint {
    let elapsed: Double
    let earned: Double
}

struct SalarySnapshot {
    var earnedToday = 0.0
    var dailySalary = 0.0
    var hourlyRate = 0.0
    var minuteRate = 0.0
    var secondRate = 0.0
    var progress = 0.0
    var status: SalaryStatus
    var workMsToday = 0.0
    var elapsedWorkMs = 0.0
    var nextTransitionMs = 0.0
    var isNightWork = false
    var earningsTimeline: [EarningsPoint] = []

    var isWorking: Bool { status == .working }
}

struct SalaryCalculator {
    private struct Span {
        let start: Date
        let end: Date
    }

    private struct Shift {
        let start: Int
        let end: Int
        let lunch: (start: Int, end: Int)?

        init?(_ config: Config) {
            guard let start = Self.minutes(config.startTime),
                  let end = Self.minutes(config.endTime), start != end else { return nil }
            self.start = start
            self.end = end < start ? end + 1440 : end

            guard config.enableLunchBreak else {
                lunch = nil
                return
            }

            guard let lunchStart = Self.minutes(config.lunchStart),
                  let lunchEnd = Self.minutes(config.lunchEnd), lunchStart != lunchEnd else { return nil }
            let breakStart = lunchStart < start ? lunchStart + 1440 : lunchStart
            var breakEnd = lunchEnd
            while breakEnd <= breakStart {
                breakEnd += 1440
            }
            guard start < breakStart, breakEnd < self.end else { return nil }
            lunch = (breakStart, breakEnd)
        }

        private static func minutes(_ time: String) -> Int? {
            let bytes = Array(time.utf8)
            guard (4...5).contains(bytes.count), bytes[bytes.count - 3] == 58 else { return nil }
            let hourDigits = bytes.dropLast(3)
            let minuteDigits = bytes.suffix(2)
            guard hourDigits.allSatisfy({ (48...57).contains($0) }),
                  minuteDigits.allSatisfy({ (48...57).contains($0) }),
                  let hour = Int(String(decoding: hourDigits, as: UTF8.self)), hour < 24,
                  let minute = Int(String(decoding: minuteDigits, as: UTF8.self)), minute < 60 else { return nil }
            return hour * 60 + minute
        }
    }

    private let calendar: Calendar

    init(timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    func snapshot(at date: Date, config: Config) -> SalarySnapshot {
        guard hasValidPay(config), !config.workdays.isEmpty,
              config.workdays.allSatisfy({ (0...6).contains($0) }),
              let shift = Shift(config) else { return SalarySnapshot(status: .invalidConfig) }

        // The previous engine truncated input timestamps to whole milliseconds.
        let nowMs = (date.timeIntervalSince1970 * 1000).rounded(.towardZero)
        let now = Date(timeIntervalSince1970: nowMs / 1000)
        let spans = resolveSpans(at: now, workdays: config.workdays, shift: shift)
        guard let first = spans.first, let last = spans.last else {
            return SalarySnapshot(status: .restDay)
        }

        var totalWorkMs = 0.0
        var elapsedWorkMs = 0.0
        for span in spans {
            let startMs = milliseconds(span.start)
            let durationMs = milliseconds(span.end) - startMs
            totalWorkMs += max(0, durationMs)
            elapsedWorkMs += min(max(0, nowMs - startMs), durationMs)
        }
        guard totalWorkMs > 0 else { return SalarySnapshot(status: .invalidConfig) }

        let workHours = totalWorkMs / 3_600_000
        let dailySalary: Double
        switch config.salaryType {
        case "daily": dailySalary = config.dailySalary
        case "hourly": dailySalary = config.hourlyRate * workHours
        default: dailySalary = config.monthlySalary / config.workDaysPerMonth
        }

        let hourlyRate = dailySalary / workHours
        let minuteRate = hourlyRate / 60
        let progress = min(max(elapsedWorkMs / totalWorkMs, 0), 1)
        let status: SalaryStatus
        let nextTransitionMs: Double
        let isNightWork: Bool
        if spans.contains(where: { $0.start <= now && now < $0.end }) {
            status = .working
            nextTransitionMs = max(0, milliseconds(last.end) - nowMs)
            let hour = calendar.component(.hour, from: now)
            isNightWork = hour >= 22 || hour < 6
        } else if elapsedWorkMs <= 0 {
            status = .beforeWork
            nextTransitionMs = max(0, milliseconds(first.start) - nowMs)
            isNightWork = false
        } else if elapsedWorkMs >= totalWorkMs {
            status = .afterWork
            nextTransitionMs = 0
            isNightWork = spans.contains(where: touchesNightWindow)
        } else {
            status = .lunchBreak
            nextTransitionMs = spans.first(where: { $0.start > now }).map {
                max(0, milliseconds($0.start) - nowMs)
            } ?? 0
            isNightWork = false
        }

        return SalarySnapshot(
            earnedToday: dailySalary * progress, dailySalary: dailySalary,
            hourlyRate: hourlyRate, minuteRate: minuteRate, secondRate: minuteRate / 60,
            progress: progress, status: status, workMsToday: totalWorkMs,
            elapsedWorkMs: elapsedWorkMs, nextTransitionMs: nextTransitionMs,
            isNightWork: isNightWork, earningsTimeline: earningsTimeline(in: spans, nowMs: nowMs, totalWorkMs: totalWorkMs)
        )
    }

    private func earningsTimeline(in spans: [Span], nowMs: Double, totalWorkMs: Double) -> [EarningsPoint] {
        let paid = spans.filter { $0.end > $0.start }
        let boundaries = Set(paid.flatMap { [milliseconds($0.start), milliseconds($0.end)] })
        guard let startMs = boundaries.min(), let endMs = boundaries.max(), endMs > startMs else { return [] }
        let currentMs = min(max(nowMs, startMs), endMs)
        let times = boundaries.filter { $0 < currentMs }.sorted() + [currentMs]
        return times.map { time in
            let accrued = paid.reduce(0.0) { sum, span in
                let spanStart = milliseconds(span.start)
                return sum + min(max(0, time - spanStart), milliseconds(span.end) - spanStart)
            }
            return EarningsPoint(elapsed: (time - startMs) / (endMs - startMs), earned: accrued / totalWorkMs)
        }
    }

    private func hasValidPay(_ config: Config) -> Bool {
        switch config.salaryType {
        case "monthly":
            return config.monthlySalary.isFinite && config.monthlySalary > 0
                && config.workDaysPerMonth > 0 && config.workDaysPerMonth <= 31
        case "daily":
            return config.dailySalary.isFinite && config.dailySalary > 0
        case "hourly":
            return config.hourlyRate.isFinite && config.hourlyRate > 0
        default:
            return false
        }
    }

    private func resolveSpans(at now: Date, workdays: [Int], shift: Shift) -> [Span] {
        let previous = workSpans(on: shiftingDay(of: now, by: -1), workdays: workdays, shift: shift)
        if let first = previous.first, let last = previous.last, first.start <= now, now <= last.end {
            return previous
        }

        let current = workSpans(on: now, workdays: workdays, shift: shift)
        if let end = previous.last?.end, now > end, calendar.isDate(now, inSameDayAs: end),
           current.first.map({ now < $0.start }) ?? true {
            return previous
        }
        return current
    }

    private func workSpans(on day: Date, workdays: [Int], shift: Shift) -> [Span] {
        guard workdays.contains(calendar.component(.weekday, from: day) - 1) else { return [] }
        let start = localTime(on: day, minutes: shift.start)
        let end = localTime(on: day, minutes: shift.end)
        if let lunch = shift.lunch {
            return [
                Span(start: start, end: localTime(on: day, minutes: lunch.start)),
                Span(start: localTime(on: day, minutes: lunch.end), end: end)
            ]
        }
        return [Span(start: start, end: end)]
    }

    private func touchesNightWindow(_ span: Span) -> Bool {
        let firstDay = shiftingDay(of: localTime(on: span.start, minutes: 0), by: -1)
        return (0..<4).contains { offset in
            let day = shiftingDay(of: firstDay, by: offset)
            let midnight = localTime(on: day, minutes: 0)
            let start = localTime(on: midnight, minutes: 22 * 60)
            let end = shiftingDay(of: localTime(on: midnight, minutes: 6 * 60), by: 1)
            return span.start < end && span.end > start
        }
    }

    private func localTime(on day: Date, minutes: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.day! += minutes / 1440
        components.hour = minutes / 60 % 24
        components.minute = minutes % 60
        return calendar.date(from: components)!
    }

    private func shiftingDay(of date: Date, by offset: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.day! += offset
        return calendar.date(from: components)!
    }

    private func milliseconds(_ date: Date) -> Double {
        (date.timeIntervalSince1970 * 1000).rounded()
    }
}
