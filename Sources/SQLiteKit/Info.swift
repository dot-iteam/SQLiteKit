//
//  Info.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-01.
//

/// Information about a column reported by SQLite table introspection.
public struct ColumnInfo: Sendable {
    let cid: Int
    let name: String
    let type: String
    let notNull: Bool
    let defaultValue: String?
}
/// Information about a table primary key reported by SQLite introspection.
public struct PrimaryKeyInfo: Sendable {
    let columns: [String]
}
/// Information about a foreign key reported by SQLite introspection.
public struct ForeignKeyInfo: Sendable {
    let id: Int
    let table: String
    let from: [String]
    let to: [String]
    let onUpdate: String
    let onDelete: String
    let match: String
}
/// Information about an index reported by SQLite introspection.
public struct IndexInfo: Sendable {
    let columns: [String]
    let unique: Bool
}
/// Information about a view reported by SQLite introspection.
public struct ViewInfo: Sendable {
    let name: String
    let sql: String
}
/// Information about a trigger reported by SQLite introspection.
public struct TriggerInfo: Sendable {
    let name: String
    let sql: String
}
/// Information about a SQLite schema entry.
public struct EntityInfo: Sendable {
    /// The schema entity name.
    public let name: String
    /// The schema entity type.
    public let type: EntityType
    /// The SQL statement SQLite stores for the entity, when available.
    public let sql: String?
}
