//
//  ListingExtension.swift
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
    /// Returns unique constraints declared on a table.
    func uniqueConstraints(table: String) throws -> [IndexInfo] {
        let sql = "select json_group_array(name) from pragma_index_list('\(table)') where origin = 'u';"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return []
        }
        let _names = getString(statement: stmt, at: 0) ?? ""
        let decoder = JSONDecoder()
        
        let names = (try? decoder.decode(Array<String>.self, from: Data(_names.utf8))) ?? []
        let _indices: [IndexInfo?] = names.map {
            try? info(table: table, index: $0, origin: "u")
        }
        var indices: [IndexInfo] = []
        _indices.forEach {
            if let index = $0 {
                indices.append(index)
            }
        }
        return indices
    }
    /// Returns the column groups that participate in unique constraints.
    func uniqueColumns(table: String) throws -> Set<[String]> {
        let _set: [[String]] = try uniqueConstraints(table: table).map { item in item.columns }
        return Set<[String]>(_set)
    }
    /// Returns `CHECK` constraint expressions declared on a table.
    func checkExpressions(table: String) throws -> [String] {
        let sql = "select sql from sqlite_schema where type='table' and name='\(table)';"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return []
        }
        let sqlString = getString(statement: stmt, at: 0) ?? ""
        return extractCheckConstraints(from: sqlString).sorted()
    }
    /// Lists SQLite schema entities.
    ///
    /// - Parameter type: Optional entity type filter.
    /// - Returns: Schema entries from `sqlite_schema`.
    func entities(type: EntityType? = nil) throws -> [EntityInfo] {
        let sql = sql("SELECT name, type, sql from sqlite_schema", type != nil ? " WHERE type='\(type!.rawValue)'" : "", ";")
        guard let stmt = prepareRaw(query: sql.sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        var result: [EntityInfo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(
EntityInfo(
                name: getString(statement: stmt, at: 0) ?? "",
                type: EntityType(
                    rawValue: getString(statement: stmt, at: 1) ?? ""
                ) ?? EntityType.other,
                sql: getString(statement: stmt, at: 2)
                )
)
        }
        return result
    }
    /// Lists columns declared on a table.
    func columns(table: String) throws -> [ColumnInfo] {
        let sql = "SELECT cid, name, type, [notnull], dflt_value FROM pragma_table_xinfo('\(table)')"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        var result: [ColumnInfo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let cid = getInt(statement: stmt, at: 0)
            let name = getString(statement: stmt, at: 1) ?? ""
            let type = getString(statement: stmt, at: 2) ?? ""
            let notNull = getInt(statement: stmt, at: 3) != 0
            let defaultValue = getString(statement: stmt, at: 4)
            result.append(ColumnInfo(cid: cid, name: name, type: type, notNull: notNull, defaultValue: defaultValue))
        }
        return result
    }
    /// Lists foreign keys declared on a table.
    func foreignKeys(table: String) throws -> [ForeignKeyInfo] {
        let sql = "select id, [table], json_group_array([from]) [from], json_group_array([to]) [to], on_update, on_delete, [match] from pragma_foreign_key_list('\(table)') group by id order by seq;"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        var result: [ForeignKeyInfo] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
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
            result.append(ForeignKeyInfo(
                id: Int(id),
                table: table,
                from: from,
                to: to,
                onUpdate: onUpdate,
                onDelete: onDelete,
                match: match
            ))
        }
        return result
    }
}
