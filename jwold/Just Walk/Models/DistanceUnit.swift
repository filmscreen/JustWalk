//
//  DistanceUnit.swift
//  Just Walk
//
//  Distance unit preference for miles/kilometers display.
//

import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles = "Miles"
    case kilometers = "Kilometers"

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var conversionFromMeters: Double {
        switch self {
        case .miles: return 0.000621371
        case .kilometers: return 0.001
        }
    }

    var metersPerUnit: Double {
        switch self {
        case .miles: return 1609.34
        case .kilometers: return 1000.0
        }
    }
}
