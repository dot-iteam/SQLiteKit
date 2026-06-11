//
//  SQLQuery.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-02.
//

/// A type that can provide SQL text.
public protocol SQLQuery {
    /// The SQL text represented by this value.
    var sql: String { get }
}
extension String: SQLQuery {
    /// Returns the string itself as SQL text.
    public var sql: String { self }
}
extension Array<String>: SQLQuery {
    /// Joins SQL fragments with newlines.
    public var sql: String { self.joined(separator: "\n") }
}
/// Creates a SQL fragment by joining string fragments with an optional separator.
public func sql(separator: String = "",_ subqueries: String...) -> some SQLQuery {
    return subqueries.joined(separator: separator)
}
/// Builds SQL text from a block of SQL fragments.
@resultBuilder
public struct QueryBuilder {
    /// Combines SQL fragments into ordered lines.
    public static func buildBlock(_ components: SQLQuery...) -> Array<String> {
        components.map { $0.sql }
    }
}
