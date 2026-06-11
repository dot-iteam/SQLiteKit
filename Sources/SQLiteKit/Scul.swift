//
//  Scul.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-05.
//
// Small-sCale-Unique-Long Identifier

import Foundation
/// Conflict resolution strategy used when two generated identifiers would collide.
public enum SculConflictResolution: Sendable {
    /// Return the previous identifier plus one.
    case increment
    /// Wait until the time-derived identifier space advances.
    case waiting
}
/// Generates compact, time-derived unique 64-bit identifiers.
///
/// `Scul` stands for "Small-sCale-Unique-Long Identifier". Generated values are
/// based on UTC date components and are monotonic within the process.
@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 1.0, *)
public actor Scul {
    /// Creates an identifier generator.
    public init() {
        
    }
    @MainActor static var last: UInt64 = 0
    @MainActor
    static func setLast(_ value: UInt64) {
        Scul.last = value
    }
    /// Generates a new identifier.
    ///
    /// - Parameter resolve: Strategy to use if the current time-derived value is
    ///   not greater than the last generated value.
    /// - Returns: A positive identifier, or `-1` if the current year is outside
    ///   the supported range.
    public func generate(resolve: SculConflictResolution = .increment) async -> Int64 {
        let time = Date.now
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.gmt
        let nanos: UInt64 = UInt64(calendar.component(.nanosecond, from: time))/10
        let secondScale: UInt64 = 100_000_000 * UInt64(calendar.component(.second, from: time))
        let minuteScale: UInt64 = 60 * 100_000_000 * UInt64(calendar.component(.minute, from: time))
        let hourScale: UInt64 = 60 * 60 * 100_000_000 * UInt64(calendar.component(.hour, from: time))
        let dayScale: UInt64 =  24 * 60 * 60 * 100_000_000 * UInt64(calendar.component(.dayOfYear, from: time))
        let yearCom = UInt64(calendar.component(.year, from: time))
        if yearCom > 10000 {
            return -1
        }
        let yearScale: UInt64 = 366 * 24 * 60 * 60 * 100_000_000 * yearCom
        let value: UInt64 = nanos + secondScale + minuteScale + hourScale + dayScale + yearScale
        let lastOne = await Scul.last
        if value <= lastOne {
            switch resolve {
            case .increment:
                await Scul.setLast(lastOne+1)
                return Int64(lastOne+1)
            case .waiting:
                let diff: UInt64 = UInt64(lastOne) - value
                let advaced: UInt64 = diff + 1
                try? await Task.sleep(nanoseconds: 10 * advaced)
                await Scul.setLast(value+advaced)
                return Int64(value+advaced)
            }
        } else {
            await Scul.setLast(value)
            return Int64(value)
        }
    }
}
