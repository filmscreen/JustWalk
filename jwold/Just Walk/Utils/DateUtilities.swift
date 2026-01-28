//
//  DateUtilities.swift
//  Just Walk
//
//  Date utilities for consistent "today" calculations and HealthKit predicates.
//

import Foundation
import HealthKit

/// Shared date utilities for HealthKit queries and date calculations
struct DateUtilities {

    // MARK: - Today Calculations

    /// Returns midnight of the current day in local timezone
    static func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Returns the end of today (start of tomorrow)
    static func endOfToday() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday()) ?? Date()
    }

    /// Returns true if the given date is today
    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - HealthKit Predicates

    /// Creates a predicate for today's samples (from midnight to now)
    static func predicateForToday() -> NSPredicate {
        HKQuery.predicateForSamples(
            withStart: startOfToday(),
            end: Date(),
            options: .strictStartDate
        )
    }

    /// Creates a predicate for a specific date (entire day)
    static func predicateForDate(_ date: Date) -> NSPredicate {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        }
        return HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
    }

    /// Creates a predicate for a date range
    static func predicateForDateRange(from startDate: Date, to endDate: Date) -> NSPredicate {
        HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
    }

    // MARK: - Verified Data Predicates (Anti-Cheat)

    /// Creates a predicate that excludes manually entered data
    static func predicateExcludingManualEntry(for date: Date) -> NSCompoundPredicate {
        let datePredicate = predicateForDate(date)
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
    }

    /// Creates a predicate for today that excludes manually entered data
    static func predicateForTodayExcludingManualEntry() -> NSCompoundPredicate {
        let datePredicate = predicateForToday()
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
    }

    // MARK: - Date Calculations

    /// Returns start of day for N days ago
    static func startOfDay(daysAgo: Int) -> Date {
        let today = startOfToday()
        return Calendar.current.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    /// Returns array of dates for the past N days (including today)
    static func pastDays(_ count: Int) -> [Date] {
        (0..<count).map { startOfDay(daysAgo: $0) }.reversed()
    }
}
