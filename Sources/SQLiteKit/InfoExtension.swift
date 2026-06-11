//
//  InfoExtension.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-06-04.
//

#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
import Foundation
public extension SQLiteDatabase {
    /// Returns metadata for a column in a table.
    func info(table: String, column: String) throws -> ColumnInfo? {
        let sql = "SELECT cid, name, type, [notnull], dflt_value FROM pragma_table_xinfo('\(table)') where name = '\(column)'"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let cid = getInt(statement: stmt, at: 0)
        let name = getString(statement: stmt, at: 1) ?? ""
        let type = getString(statement: stmt, at: 2) ?? ""
        let notNull = getInt(statement: stmt, at: 3) != 0
        let defaultValue = getString(statement: stmt, at: 4)
        return ColumnInfo(cid: Int(cid), name: name, type: type, notNull: notNull, defaultValue: defaultValue)
    }
    /// Returns primary key metadata for a table.
    ///
    /// - Important: The current implementation queries SQLite table metadata and
    ///   is intended to use the supplied table name.
    func primaryKey(table: String) throws -> PrimaryKeyInfo? {
        let sql = "select json_group_array(name) from pragma_table_info('\(table)') where pk > 0 order by pk"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let _columns = getString(statement: stmt, at: 0) ?? ""
        let decoder = JSONDecoder()
        
        let columns = try? decoder.decode(Array<String>.self, from: Data(_columns.utf8))
        return PrimaryKeyInfo(columns: columns ?? [])
    }
    /// Returns metadata for an index on a table.
    ///
    /// - Parameters:
    ///   - table: The table that owns the index.
    ///   - index: The index name.
    ///   - origin: SQLite's index origin filter, such as `c` for created indexes
    ///     or `u` for unique constraints.
    func info(table: String, index: String, origin: String = "c") throws -> IndexInfo? {
        let sql1 = "select [unique] from pragma_index_list('\(table)') where origin = '\(origin)' and name = '\(index)'"
        guard let stmt1 = prepareRaw(query: sql1) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt1) }
        guard sqlite3_step(stmt1) == SQLITE_ROW else {
            return nil
        }
        let unique = getInt(statement: stmt1, at: 0) != 0
        let sql = "select json_group_array(name) from pragma_index_xinfo('\(index)') order by seqno;"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let _columns = getString(statement: stmt, at: 0) ?? ""
        let decoder = JSONDecoder()
        var columns = try? decoder.decode(Array<String?>.self, from: Data(_columns.utf8))
        columns = columns?.filter { $0 != nil && $0 != "" }
        return IndexInfo(columns: columns?.map { $0! } ?? [], unique: unique)
    }
    /// Returns metadata for a foreign key that matches the supplied relationship.
    func info(table: String, foreignKey: [String], references: String, on: [String]) throws -> ForeignKeyInfo? {
        let encoder = JSONEncoder()
        let _fromList = (try? encoder.encode(foreignKey)) ?? Data("[]".utf8)
        let _toList = (try? encoder.encode(on)) ?? Data("[]".utf8)
        let fromList = String(data: _fromList, encoding: .utf8) ?? "[]"
        let toList = String(data: _toList, encoding: .utf8) ?? "[]"
        let sql = "select * from (select id, [table], json_group_array([from]) [from], json_group_array([to]) [to], on_update, on_delete, [match] from pragma_foreign_key_list('\(table)') group by id order by seq) where [table] = '\(references)' and [from] = '\(fromList)' and [to] = '\(toList)'"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let id = getInt(statement: stmt, at: 0)
        let table = getString(statement: stmt, at: 1) ?? ""
        let _from = getString(statement: stmt, at: 2) ?? ""
        let _to = getString(statement: stmt, at: 3) ?? ""
        let onUpdate = getString(statement: stmt, at: 4) ?? ""
        let onDelete = getString(statement: stmt, at: 5) ?? ""
        let match = getString(statement: stmt, at: 6) ?? ""
        let jsonDecoder = JSONDecoder()
        let from: [String] = (try? jsonDecoder.decode([String].self, from: Data(_from.utf8))) ?? []
        let to: [String] = (try? jsonDecoder.decode([String].self, from: Data(_to.utf8))) ?? []
        return ForeignKeyInfo(
            id: Int(id),
            table: table,
            from: from,
            to: to,
            onUpdate: onUpdate,
            onDelete: onDelete,
            match: match
        )
    }
    /// Returns metadata for a view.
    func info(view: String) throws -> ViewInfo? {
        let sql = "select name, sql from sqlite_schema where type='view' and name='\(view)';"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let name = getString(statement: stmt, at: 0) ?? ""
        let sqlString = getString(statement: stmt, at: 1) ?? ""
        return ViewInfo(name: name, sql: sqlString)
    }
    /// Returns metadata for a trigger.
    func info(trigger: String) throws -> TriggerInfo? {
        let sql = "select name, sql from sqlite_schema where type='trigger' and name='\(trigger)';"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let name = getString(statement: stmt, at: 0) ?? ""
        let sqlString = getString(statement: stmt, at: 1) ?? ""
        return TriggerInfo(name: name, sql: sqlString)
    }
}
