//
//  Mapper.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-04.
//

/// A mutable value that can receive SQLite column values by index.
public protocol RowMapper: Sendable {
    /// Assigns a column value to the receiver.
    mutating func set(value: Sendable?, at index: Int)
}
/// Describes whether a query should reuse a named prepared statement.
public enum Precompilation: Sendable {
    /// Reuse or create a precompiled statement stored under the provided name.
    case named(String)
    /// Do not use a precompiled statement.
    case none
}
/// Describes a SQL statement and its bound parameters.
public protocol QueryMapper: Sendable {
    /// The precompilation behavior for this query.
    var precompilation: Precompilation { get }
    /// The SQL text to execute.
    var query: String { get }
    /// Values to bind to positional placeholders in ``query``.
    var parameters: [SQLParameter] { get }
}
/// Describes a query that maps each returned row into a custom record type.
public protocol QueryResultMapper<Result>: QueryMapper where Result: RowMapper {
    /// The mapped row type.
    associatedtype Result: RowMapper
    /// Creates a new record before SQLiteKit assigns column values to it.
    func newRecord() -> Result
}
