// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
import Foundation
fileprivate nonisolated(unsafe) let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
/// An error reported by SQLiteKit or the underlying SQLite connection.
public enum SQLiteError: Error {
    /// A SQLite error message.
    case error(String)
}
/// A SQL statement with positional parameters ready to bind.
public struct PreparedStatement : Sendable {
    /// The SQL text to prepare.
    public let query: String
    var parameters: [SQLParameter]
    /// Creates a prepared statement description.
    ///
    /// - Parameters:
    ///   - query: SQL text containing positional `?` placeholders.
    ///   - parameters: Values to bind in placeholder order.
    public init(query: String, parameters: [SQLParameter] = []) {
        self.query = query
        self.parameters = parameters
    }
    /// Creates a prepared statement description from a parameter builder closure.
    public init(query: String, parameters: () -> [SQLParameter]) {
        self.init(query: query, parameters: parameters())
    }
    /// Appends a value to the statement's positional parameter list.
    public mutating func add(parameter: SQLParameter) {
        parameters.append(parameter)
    }
}

/// An actor-isolated SQLite connection.
///
/// `SQLiteDatabase` serializes access to a SQLite database handle, configures
/// common pragmas during initialization, executes SQL, binds parameters, manages
/// reusable prepared statements, and inspects or synchronizes schema objects.
public actor SQLiteDatabase {
    var db: OpaquePointer
    let synchronous: SQLiteSynchronous
    var precompiled: [String: OpaquePointer] = [:]
    /// Prepares and stores a named statement for later reuse.
    ///
    /// The statement can be executed with ``result(header:precompiled:parameters:)``.
    public func precompile(name: String, query: SQLQuery) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare(db, query.sql, -1, &stmt, nil) == SQLITE_OK else {
            return
        }
        precompiled[name] = stmt
    }
    /// Builds, prepares, and stores a named statement for later reuse.
    public func precompile(name: String, @QueryBuilder query: @Sendable () -> SQLQuery) {
        precompile(name: name, query: query())
    }
    nonisolated(unsafe) var closed: Bool = false
    /// Opens a SQLite database and applies SQLiteKit's startup pragmas.
    ///
    /// The initializer enables foreign keys, sets WAL journal mode, applies the
    /// requested synchronous mode, and optionally configures cache and memory map
    /// sizes.
    ///
    /// - Parameters:
    ///   - path: Filesystem path for the SQLite database. Use `":memory:"` for
    ///     an in-memory database.
    ///   - tempStore: Temporary storage preference.
    ///   - synchronous: SQLite synchronous write mode.
    ///   - cacheSize: Optional SQLite cache size pragma value.
    ///   - mmapSize: Optional SQLite memory map size pragma value.
    public init?(path: String, tempStore: SQLiteTempStore = .memory, synchronous: SQLiteSynchronous = .normal, cacheSize: Int? = nil, mmapSize: Int? = nil) throws {
        var _db: OpaquePointer?
        if sqlite3_open(path, &_db) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(_db))
            throw SQLiteError.error(message)
        }
        guard let _db else { return nil }
        self.db = _db
        self.synchronous = synchronous
        var pragmaStatements = [
            "PRAGMA foreign_keys = ON;",
            "PRAGMA journal_mode = WAL;",
            "PRAGMA synchronous = \(synchronous.rawValue);"
            
        ]
        if let mmapSize {
            pragmaStatements.append("PRAGMA mmap_size = \(mmapSize);")
        }
        if let cacheSize {
            pragmaStatements.append("PRAGMA cache_size = \(cacheSize);")
        }
        if case .memory = tempStore {
            pragmaStatements.append("PRAGMA temp_store = \(tempStore.rawValue);")
        }
        try executeNoIsolate(db: _db, query: pragmaStatements)
    }
    func prepareRaw(query: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        return stmt
    }
    /// Creates or synchronizes schema entities with the database.
    ///
    /// Tables are created when missing. When SQLiteKit detects a supported table
    /// shape change, it creates a replacement table, copies data from the old
    /// table, drops the old table, and renames the replacement. Views, triggers,
    /// and indexes are dropped and recreated when their stored definition differs
    /// from the requested definition.
    ///
    /// - Parameters:
    ///   - mode: Comparison mode used when checking existing constraints.
    ///   - entities: Schema entities to create or synchronize.
    public func schema(mode: SchemaMatchMode = .strict, @SchemeBuilder entities: @Sendable () -> [any SchemaEntity]) throws {
        print("Starting SQLite Schema Building...")
        var indices: [Index] = []
        for entity in entities() {
            switch entity {
            case let table as Table:
                indices.append(contentsOf: table.indices)
                guard table.columns.count > 0 else { continue }
                if !(try exist(table: table.name)) {
                    print("Creating table: \(table.name)")
                    try? execute {
                        Table
                            .creationStatement(
                                name: table.name,
                                columns: table.columns,
                                primaryKey: table.primaryKey,
                                foreignKeys: table.foreignKeys,
                                uniqueConstraints: table.uniqueConstraints,
                                checks: table.checks
                            )
                    }
                } else {
                    var foundChange: Bool = false
                    if let schemePrimaryKey = table.primaryKey {
                        let primaryKeyInfo = try primaryKey(table: table.name)
                        if schemePrimaryKey.columns
                            .map({ $0.name }) != primaryKeyInfo?.columns {
                            foundChange = true
                            print("Found change in primary key of table: \(table.name)")
                        }
                    }
                    for column in table.columns {
                        if !(try exist(table: table.name, column: column.name)) {
                            try? execute {
                                "ALTER TABLE \(table.name) ADD COLUMN"
                                column.description
                            }
                            print("Found additional column of table: \(table.name) column: \(column.name)")
                        } else {
                            guard let info = try? info(table: table.name, column: column.name) else {
                                continue
                            }
                            if info.type != column.type || info.notNull != column.isNotNull || info.defaultValue != column.defaultValue {
                                foundChange = true
                            }
                        }
                    }
                    let jsonEncoder = JSONEncoder()
                    func sortedStringListJson(_ list: [String]) -> String {
                        guard let data = try? jsonEncoder.encode( list.sorted()) else {
                            return "[]"
                        }
                        return String(data: data, encoding: .utf8) ?? "[]"
                    }
                    if case .strict = mode {
                        let newReferences = table.foreignKeys.map { sortedStringListJson($0.columns) }.sorted()
                        let currentReferences = try foreignKeys(table: table.name).map { sortedStringListJson($0.from) }.sorted()
                        if newReferences != currentReferences {
                            foundChange = true
                            print("Found change in foreign keys of table: \(table.name) current: \(currentReferences) new: \(newReferences)")
                        }
                    } else {
                        for foreignKey in table.foreignKeys {
                            let info = try info(
                                table: table.name,
                                foreignKey: foreignKey.columns,
                                references: foreignKey.reference,
                                on: foreignKey.on
                            )
                            if foreignKey.columns != info?.from || foreignKey.on != info?.to {
                                foundChange = true
                                print("Found change in foreign key of table: \(table.name) columns: \(foreignKey.columns) references: \(foreignKey.reference) on: \(foreignKey.on)")
                            }
                        }
                    }
                    if case .strict = mode {
                        let uniqueColumns = try uniqueColumns(table: table.name)
                        let currentUniqueSet = uniqueColumns.map(sortedStringListJson).sorted()
                        let newUniqueSet = table.uniqueConstraints.map { sortedStringListJson($0.columns.map(\.name)) }.sorted()
                        if newUniqueSet != currentUniqueSet {
                            foundChange = true
                            print("Found change in unique constraints of table: \(table.name) current: \(currentUniqueSet) new: \(newUniqueSet)")
                        }
                    } else {
                        let uniqueColumns = try uniqueColumns(table: table.name)
                        for uniqueConstraint in table.uniqueConstraints {
                            if !uniqueColumns.contains(uniqueConstraint.columns.map(\.name)) {
                                foundChange = true
                                print(
                                    "Found change in unique constraint of table: \(table.name) columns: \(uniqueConstraint.columns)"
                                )
                            }
                        }
                    }
                    let orignalChecks = table.checks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.sorted()
                    let currentChecks = try checkExpressions(table: table.name).map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }.sorted()
                    if orignalChecks != currentChecks {
                        foundChange = true
                        print("Found change in check constraint of table: \(table.name) as: \(orignalChecks)")
                    }
                    if foundChange {
                        var backupName = "_\(table.name)"
                        var tries = 0
                        while true {
                            do {
                                let backupExist = try exist(table: backupName)
                                if backupExist {
                                    backupName = "_\(backupName)"
                                    if tries < 64 {
                                        tries += 1
                                        continue
                                    } else {
                                        break
                                    }
                                } else {
                                    break
                                }
                            } catch {
                                break
                            }
                        }
                        print("Changing table: \(table.name) temporary backup: \(backupName)")
                        try execute {
                            "PRAGMA foreign_keys = OFF;"
                            "BEGIN;"
                            "PRAGMA legacy_alter_table = ON;"
                            "\(Table.creationStatement(name: backupName, columns: table.columns, primaryKey: table.primaryKey, foreignKeys: table.foreignKeys, uniqueConstraints: table.uniqueConstraints, checks: table.checks))"
                            "INSERT INTO [\(backupName)] (\(table.columns.filter { $0.generation == nil }.map { "[\($0.name)]" }.joined(separator: ",")))"
                            "SELECT \(table.columns.filter { $0.generation == nil }.map { "[\($0.name)]" }.joined(separator: ","))"
                            "FROM [\(table.name)];"
                            "DROP TABLE [\(table.name)];"
                            "ALTER TABLE [\(backupName)] RENAME TO [\(table.name)];"
                            "PRAGMA legacy_alter_table = OFF;"
                            "COMMIT;"
                            "PRAGMA foreign_keys = ON;"
                        }
                    }
                }
            case let index as Index:
                indices.append(index)
            case let view as View:
                let info = try info(view: view.name)
                if info?.sql != view.sql {
                    print("Creating/Modifying view: \(view.name)")
                    try execute {
                        "DROP VIEW IF EXISTS [\(view.name)];"
                        view.sql
                    }
                }
            case let trigger as Trigger:
                let info = try info(trigger: trigger.name)
                if info?.sql != trigger.sql {
                    print("Creating/Modifying trigger: \(trigger.name)")
                    try execute {
                        "DROP TRIGGER IF EXISTS [\(trigger.name)];"
                        trigger.sql
                    }
                }
            default:
                break
            }
        }
        for index in indices {
            let info = try info(table: index.table, index: index.name)
            if info?.columns != index.columns.map(\.name) || info?.unique != index.unique {
                print("Creating/Modifying index: \(index.name)")
                try? execute {
                    "DROP INDEX IF EXISTS [\(index.name)];"
                    index.description
                }
            }
        }
    }
    func getHeader(for statement: OpaquePointer) -> [String] {
        let count = sqlite3_column_count(statement)
        var result: [String] = []
        for i in 0..<count {
            let name = String(cString: sqlite3_column_name(statement, Int32(i)))
            result.append(name)
        }
        return result
    }
    func bind(statement stmt: OpaquePointer, parameters: [SQLParameter]) throws {
        var index: Int32 = 1
        for parameter in parameters {
            switch parameter {
            case .int(let value):
                sqlite3_bind_int(stmt, index, Int32(value))
            case .text(let value):
                let bytesCount = [UInt8](value.utf8).count
                sqlite3_bind_text64(
                    stmt,
                    index,
                    value,
                    UInt64(bytesCount),
                    SQLITE_TRANSIENT_DESTRUCTOR,
                    UInt8(SQLITE_UTF8)
                )
                
            case .blob(let value):
                _ = value.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
                    if buffer.count <= Int32.max {
                        sqlite3_bind_blob(
                            stmt,
                            index,
                            buffer.baseAddress,
                            Int32(buffer.count),
                            SQLITE_TRANSIENT_DESTRUCTOR
                        )
                    } else {
                        sqlite3_bind_blob64(
                            stmt,
                            index,
                            buffer.baseAddress,
                            UInt64(buffer.count),
                            SQLITE_TRANSIENT_DESTRUCTOR
                        )
                    }
                    
                }
            case .integer(let value):
                sqlite3_bind_int64(stmt, index, Int64(value))
            case .real(let value):
                sqlite3_bind_double(stmt, index, value)
                
            }
            index += 1
        }
    }
    func bind(query: String, parameters: [SQLParameter]) throws -> OpaquePointer? {
        guard let stmt = prepareRaw(query: query) else {
            throw lastError()
        }
        try bind(statement: stmt, parameters: parameters)
        return stmt
    }
    func bind(prepared statement: PreparedStatement) throws -> OpaquePointer? {
        return try bind(query: statement.query, parameters: statement.parameters)
    }
    /// Executes a prepared statement description and returns tabular results.
    ///
    /// - Parameters:
    ///   - header: Pass `true` to include column names in the result.
    ///   - statement: Statement text and parameters to bind.
    /// - Returns: The result rows and effect metadata, or `nil` if the statement
    ///   could not be prepared.
    public func result(header: Bool = false, parepared statement: PreparedStatement) throws -> SQLResult? {
        guard let stmt = try bind(prepared: statement) else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        let header = header ? getHeader(for: stmt) : nil
        var result: [[Sendable?]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = getRow(statement: stmt)
            result.append(row)
        }
        return SQLResult(header: header, records: result, affected: sqlite3_changes64(db), lastInsertRowId: sqlite3_last_insert_rowid(db))
    }
    /// Executes a previously precompiled statement by name.
    ///
    /// - Parameters:
    ///   - header: Pass `true` to include column names in the result.
    ///   - name: Name supplied to ``precompile(name:query:)``.
    ///   - parameters: Values to bind in placeholder order.
    /// - Returns: The result rows and effect metadata, or `nil` when no statement
    ///   exists for `name`.
    public func result(header: Bool = false, precompiled name: String, parameters: [SQLParameter]) throws -> SQLResult? {
        guard let stmt = self.precompiled[name] else {
            return nil
        }
        try bind(statement: stmt, parameters: parameters)
        defer {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }
        let header = header ? getHeader(for: stmt) : nil
        var result: [[Sendable?]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = getRow(statement: stmt)
            result.append(row)
        }
        return SQLResult(
            header: header,
            records: result,
            affected: sqlite3_changes64(db),
            lastInsertRowId: sqlite3_last_insert_rowid(db)
        )
    }
    func getInt(statement: OpaquePointer?, at: Int32) -> Int {
        Int(sqlite3_column_int(statement, at))
    }
    func getString(statement: OpaquePointer?, at: Int32) -> String? {
        let cString = sqlite3_column_text(statement, at)
        guard let cString else { return nil }
        return String(cString: cString)
    }
    func getReal(statement: OpaquePointer?, at: Int32) -> Double {
        sqlite3_column_double(statement, at)
    }
    func getBlob(statement: OpaquePointer?, at: Int32) -> Data? {
        guard let cString = sqlite3_column_blob(statement, at) else { return nil }
        let length = Int(sqlite3_column_bytes(statement, at))
        return Data(bytes: cString, count: length)
    }
    func getInteger(statement: OpaquePointer?, at: Int32) -> Int64 {
        sqlite3_column_int64(statement, at)
    }
    func getRow(statement: OpaquePointer?) -> [Sendable?] {
        let count = sqlite3_column_count(statement)
        var entries: [Sendable?] = []
        for i in 0..<count {
            let type = sqlite3_column_type(statement, i)
            switch type {
            case SQLITE_TEXT:
                entries.append(getString(statement: statement, at: i))
            case SQLITE_INTEGER:
                entries.append(getInteger(statement: statement, at: i))
            case SQLITE_FLOAT:
                entries.append(getReal(statement: statement, at: i))
            case SQLITE_BLOB:
                entries.append(getBlob(statement: statement, at: i))
            default:
                entries.append(nil)
            }
        }
        return entries
    }
    /// Executes a result mapper and converts rows into custom values.
    ///
    /// The mapper supplies SQL text, parameters, precompilation behavior, and a
    /// fresh record for every returned row.
    public func result<Mapper: QueryResultMapper>(mapper: Mapper) throws -> SQLResultSet<Mapper.Result> {
        var statement: OpaquePointer?
        var reuse: Bool = false
        switch mapper.precompilation {
        case .named(let name):
            if let stmt = precompiled[name] {
                statement = stmt
                try bind(statement: stmt, parameters: mapper.parameters)
            } else {
                statement = try bind(
                    query: mapper.query,
                    parameters: mapper.parameters
                )
                precompiled[name] = statement
            }
            reuse = true
        case .none:
            statement = try bind(
                query: mapper.query,
                parameters: mapper.parameters
            )
        }
        defer {
            if reuse {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
            } else {
                sqlite3_finalize(statement)
            }
        }
        var result: [Mapper.Result] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let row = getRow(statement: statement)
            var record = mapper.newRecord()
            var index = 0
            row.forEach { item in
                record.set(value: item, at: index)
                index += 1
            }
            result.append(record)
        }
        return SQLResultSet(
            values: result,
            affected: sqlite3_changes64(db),
            lastInsertRowId: sqlite3_last_insert_rowid(db)
        )
    }
    /// Executes a result mapper and returns only mapped values.
    public func values<Mapper: QueryResultMapper>(mapper: Mapper) throws -> [Mapper.Result] {
        try result(mapper: mapper).values
    }
    /// Executes a result mapper and returns the first mapped value.
    public func scalar<Mapper: QueryResultMapper>(mapper: Mapper) throws -> Mapper.Result? {
        try result(mapper: mapper).values.first
    }
    /// Executes a mapper for a statement that is expected to produce side effects.
    public func result<Mapper: QueryMapper>(mapper: Mapper) throws -> SQLEffect {
        var statement: OpaquePointer?
        var reuse: Bool = false
        switch mapper.precompilation {
        case .named(let name):
            if let stmt = precompiled[name] {
                statement = stmt
                try bind(statement: stmt, parameters: mapper.parameters)
            } else {
                statement = try bind(
                    query: mapper.query,
                    parameters: mapper.parameters
                )
                precompiled[name] = statement
            }
            reuse = true
        case .none:
            statement = try bind(
                query: mapper.query,
                parameters: mapper.parameters
            )
        }
        defer {
            if reuse {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
            } else {
                sqlite3_finalize(statement)
            }
        }
        while sqlite3_step(statement) == SQLITE_ROW {}
        return SQLEffect(
            affected: sqlite3_changes64(db),
            lastInsertRowId: sqlite3_last_insert_rowid(db)
        )
    }
    /// Returns whether a table exists.
    public func exist(table: String) throws -> Bool {
        let sql = "SELECT COUNT(*) FROM sqlite_schema WHERE type='table' AND name='\(table)'"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return false
        }
        let count = sqlite3_column_int(stmt, 0)
        return count > 0
    }
    /// Returns whether a column exists in a table.
    public func exist(table: String, column: String) throws -> Bool {
        let sql = "SELECT COUNT(*) FROM pragma_table_xinfo('\(table)') where name='\(column)'"
        guard let stmt = prepareRaw(query: sql) else {
            throw lastError()
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return false
        }
        let count = sqlite3_column_int(stmt, 0)
        return count > 0
    }
    nonisolated func executeNoIsolate(db: OpaquePointer, query: SQLQuery) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, query.sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown Error"
            sqlite3_free(errorMessage)
            throw SQLiteError.error(message)
        }
    }
    /// Executes SQL without returning rows.
    public func execute(query: SQLQuery) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, query.sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown Error"
            sqlite3_free(errorMessage)
            throw SQLiteError.error(message)
        }
    }
    /// Builds and executes SQL without returning rows.
    public func execute(@QueryBuilder query: () -> SQLQuery) throws {
        try execute(query: query())
    }
    /// Returns the last error message reported by the SQLite connection.
    public func lastError() -> SQLiteError {
        let message = sqlite3_errmsg(db).flatMap { String(cString: $0) } ?? "Unknown SQLite error"
        return .error(message)
    }
    /// Finalizes precompiled statements and closes the SQLite connection.
    public func close() {
        for stmt in precompiled.values {
            sqlite3_finalize(stmt)
        }
        sqlite3_close(db)
    }
}
