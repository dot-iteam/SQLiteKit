import Foundation
import Testing
@testable import SQLiteKit

private func withMemoryDatabase<T>(_ body: (SQLiteDatabase) async throws -> T) async throws -> T {
    let database = try #require(try SQLiteDatabase(path: ":memory:"))
    do {
        let result = try await body(database)
        await database.close()
        return result
    } catch {
        await database.close()
        throw error
    }
}

private struct UserRecord: RowMapper, Equatable {
    var id: Int64 = 0
    var name: String = ""
    var score: Double = 0

    mutating func set(value: Sendable?, at index: Int) {
        switch index {
        case 0:
            id = value as? Int64 ?? 0
        case 1:
            name = value as? String ?? ""
        case 2:
            score = value as? Double ?? 0
        default:
            break
        }
    }
}

private struct CountRecord: RowMapper, Equatable {
    var value: Int64 = 0

    mutating func set(value: Sendable?, at index: Int) {
        if index == 0 {
            self.value = value as? Int64 ?? 0
        }
    }
}

private struct UsersByMinimumScoreMapper: QueryResultMapper {
    let minimumScore: Double
    let precompilation: Precompilation = .named("usersByMinimumScore")
    var parameters: [SQLParameter] { [.real(minimumScore)] }
    let query = "SELECT id, name, score FROM users WHERE score >= ? ORDER BY id;"

    func newRecord() -> UserRecord {
        UserRecord()
    }
}

private struct UserCountMapper: QueryResultMapper {
    let precompilation: Precompilation = .none
    let parameters: [SQLParameter] = []
    let query = "SELECT COUNT(*) FROM users;"

    func newRecord() -> CountRecord {
        CountRecord()
    }
}

private struct InsertUserMapper: QueryMapper {
    let id: Int64
    let name: String
    let score: Double
    let precompilation: Precompilation
    let query = "INSERT INTO users(id, name, score) VALUES (?, ?, ?);"
    var parameters: [SQLParameter] { [.integer(id), .text(name), .real(score)] }
}

@Test func sqlQueryBuilderCombinesFragmentsInOrder() {
    let query = sql(separator: " ", "SELECT *", "FROM users", "WHERE id = ?")
    #expect(query.sql == "SELECT * FROM users WHERE id = ?")

    let built = QueryBuilder.buildBlock(
        "CREATE TABLE users(id INTEGER);",
        "CREATE INDEX users_id ON users(id);"
    )
    #expect(built.sql == "CREATE TABLE users(id INTEGER);\nCREATE INDEX users_id ON users(id);")
}

@Test func enumsExposeSQLiteRawValues() {
    #expect(SQLiteSynchronous.off.rawValue == "OFF")
    #expect(SQLiteSynchronous.normal.rawValue == "NORMAL")
    #expect(SQLiteSynchronous.full.rawValue == "FULL")
    #expect(SQLiteTempStore.memory.rawValue == "MEMORY")
    #expect(SQLiteTempStore.none.rawValue == "none")
    #expect(EntityType.table.rawValue == "table")
    #expect(EntityType.view.rawValue == "view")
    #expect(EntityType.trigger.rawValue == "trigger")
    #expect(EntityType.index.rawValue == "index")
    #expect(EntityType.other.rawValue == "")
}

@Test func rowSupportsNameIndexLookupAndDescription() {
    let row = Row(entries: [
        ("id", Int64(7)),
        ("name", "Fatima"),
        (nil, "ignored")
    ])

    #expect(row["id"] as? Int64 == 7)
    #expect(row["name"] as? String == "Fatima")
    #expect(row[0] as? Int64 == 7)
    #expect(row[2] as? String == "ignored")
    let missingName: String? = row["missing"] as? String
    #expect(missingName == nil)
    #expect(row.description.contains("Fatima"))
}

@Test func schemaTypesProduceExpectedSQLDescriptions() {
    let column = Column(name: "full_name", type: "TEXT", notNull: true, defaultValue: "''")
        .generation(.virtual("first_name || ' ' || last_name"))
    let storedColumn = Column(name: "name_length", type: "INTEGER")
        .generation(.stored("length(full_name)"))
    let primaryKey = PrimaryKey(name: "users_pk", columns: ["id"]).order("ASC")
    let foreignKey = ForeignKey(name: "orders_user_fk", columns: ["user_id"], reference: "users", on: ["id"])
    let unique = UniqueConstraint(name: "users_email_unique", columns: ["email"])
    let index = Index(name: "users_name_index", table: "users", columns: ["name"], unique: true)
    let view = View(name: "active_users") { "CREATE VIEW active_users AS SELECT * FROM users;" }
    let trigger = Trigger(name: "users_audit_insert") { "CREATE TRIGGER users_audit_insert AFTER INSERT ON users BEGIN SELECT 1; END;" }

    #expect("email".name == "email")
    #expect("email".sqlName == "[email]")
    #expect(OrderedColumn(name: "created_at").sqlName == "[created_at] ASC")
    #expect(column.description == "[full_name] TEXT NOT NULL DEFAULT '' GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL")
    #expect(storedColumn.description == "[name_length] INTEGER GENERATED ALWAYS AS (length(full_name)) STORED")
    #expect(primaryKey.description == "CONSTRAINT [users_pk] PRIMARY KEY ([id])")
    #expect(primaryKey.order == ["ASC"])
    #expect(foreignKey.description == "CONSTRAINT orders_user_fk FOREIGN KEY ([user_id]) REFERENCES users([id])")
    #expect(unique.description == "CONSTRAINT [users_email_unique] UNIQUE([email])")
    #expect(index.description == "CREATE UNIQUE INDEX [users_name_index] ON [users]([name])")
    #expect(view.description == view.sql)
    #expect(trigger.description == trigger.sql)

    let tableSQL = Table.creationStatement(
        name: "users",
        columns: [Column(name: "id", type: "INTEGER")],
        primaryKey: primaryKey,
        foreignKeys: [],
        uniqueConstraints: [unique],
        checks: ["id > 0"]
    )
    #expect(tableSQL == "CREATE TABLE [users]([id] INTEGER,CONSTRAINT [users_pk] PRIMARY KEY ([id]),CONSTRAINT [users_email_unique] UNIQUE([email]),CHECK (id > 0));")
}

@Test func databaseInitializerAppliesExpectedPragmas() async throws {
    try await withMemoryDatabase { database in
        let foreignKeys = try await #require(database.result(parepared: PreparedStatement(query: "PRAGMA foreign_keys;")))
        let tempStore = try await #require(database.result(parepared: PreparedStatement(query: "PRAGMA temp_store;")))

        #expect(foreignKeys.records.first?.first as? Int64 == 1)
        #expect(tempStore.records.first?.first as? Int64 == 2)
    }
}

@Test func schemaCreatesTablesIndexesAndIntrospectionMetadata() async throws {
    try await withMemoryDatabase { database in
        try await database.schema {
            Table(name: "users")
                .column(name: "id", type: "INTEGER", notNull: true)
                .column(name: "email", type: "TEXT", notNull: true)
                .column(name: "score", type: "REAL", defaultValue: "0")
                .primaryKey(name: "users_pk", columns: ["id"])
                .unique(name: "users_email_unique", columns: ["email"])
                .index(name: "users_score_index", columns: ["score"])
                .check("score >= 0")
        }

        #expect(try await database.exist(table: "users"))
        #expect(try await database.exist(table: "users", column: "email"))
        #expect(try await database.exist(table: "missing") == false)
        #expect(try await database.exist(table: "users", column: "missing") == false)
        #expect(try await database.columns(table: "users").map(\.name) == ["id", "email", "score"])
        #expect(try await database.info(table: "users", column: "email")?.notNull == true)
        #expect(try await database.info(table: "users", column: "missing") == nil)
        #expect(try await database.primaryKey(table: "users")?.columns == ["id"])
        #expect(try await database.info(table: "users", index: "users_score_index")?.columns == ["score"])
        #expect(try await database.info(table: "users", index: "missing") == nil)
        #expect(try await database.uniqueConstraints(table: "users").count == 1)
        #expect(try await database.uniqueColumns(table: "users").contains(["email"]))
        #expect(try await database.checkExpressions(table: "users") == ["score >= 0"])
        #expect(try await database.entities(type: .table).contains { $0.name == "users" && $0.type == .table })
    }
}

@Test func schemaCreatesForeignKeysViewsAndTriggers() async throws {
    try await withMemoryDatabase { database in
        try await database.schema {
            Table(name: "users")
                .column(name: "id", type: "INTEGER", notNull: true)
                .column(name: "active", type: "INTEGER", defaultValue: "1")
                .primaryKey(name: "users_pk", columns: ["id"])
            Table(name: "orders")
                .column(name: "id", type: "INTEGER", notNull: true)
                .column(name: "user_id", type: "INTEGER", notNull: true)
                .primaryKey(name: "orders_pk", columns: ["id"])
                .foreignKey(name: "orders_user_fk", columns: ["user_id"], references: "users", on: ["id"])
            Table(name: "audit_log")
                .column(name: "message", type: "TEXT")
            View(name: "active_users") {
                "CREATE VIEW active_users AS SELECT id FROM users WHERE active = 1;"
            }
            Trigger(name: "orders_insert_audit") {
                "CREATE TRIGGER orders_insert_audit AFTER INSERT ON orders BEGIN INSERT INTO audit_log(message) VALUES ('inserted'); END;"
            }
        }

        let foreignKeys = try await database.foreignKeys(table: "orders")
        #expect(foreignKeys.count == 1)
        #expect(foreignKeys.first?.table == "users")
        #expect(foreignKeys.first?.from == ["user_id"])
        #expect(foreignKeys.first?.to == ["id"])
        #expect(try await database.info(table: "orders", foreignKey: ["user_id"], references: "users", on: ["id"])?.table == "users")
        #expect(try await database.info(table: "orders", foreignKey: ["missing"], references: "users", on: ["id"]) == nil)
        #expect(try await database.info(view: "active_users")?.name == "active_users")
        #expect(try await database.info(trigger: "orders_insert_audit")?.name == "orders_insert_audit")
        #expect(try await database.info(view: "missing") == nil)
        #expect(try await database.info(trigger: "missing") == nil)
        #expect(try await database.entities(type: .view).contains { $0.name == "active_users" })
        #expect(try await database.entities(type: .trigger).contains { $0.name == "orders_insert_audit" })

        try await database.execute {
            "INSERT INTO users(id, active) VALUES (1, 1);"
            "INSERT INTO orders(id, user_id) VALUES (10, 1);"
        }
        let audit = try await #require(database.result(parepared: PreparedStatement(query: "SELECT message FROM audit_log;")))
        #expect(audit.records.first?.first as? String == "inserted")
    }
}

@Test func schemaCanAddColumnsAndCreateGeneratedColumns() async throws {
    try await withMemoryDatabase { database in
        try await database.schema {
            Table(name: "people")
                .column(name: "first_name", type: "TEXT")
        }
        try await database.schema(mode: .flexible) {
            Table(name: "people")
                .column(name: "first_name", type: "TEXT")
                .column(name: "last_name", type: "TEXT", defaultValue: "''")
                .column(name: "full_name", type: "TEXT") { column in
                    column.generation(.virtual("first_name || ' ' || last_name"))
                }
        }

        #expect(try await database.columns(table: "people").map(\.name) == ["first_name", "last_name", "full_name"])
    }
}

@Test func preparedStatementsBindAllParameterTypesAndReturnTypedRows() async throws {
    try await withMemoryDatabase { database in
        let payload = Data([0x01, 0x02])
        let statement = PreparedStatement(query: "SELECT ? AS small, ? AS large, ? AS label, ? AS payload, ? AS amount, NULL AS empty;") {
            [
                .int(12),
                .integer(9_000_000_000),
                .text("first"),
                .blob(payload),
                .real(1.5)
            ]
        }

        let result = try await #require(database.result(header: true, parepared: statement))
        #expect(result.header == ["small", "large", "label", "payload", "amount", "empty"])
        #expect(result.records.count == 1)
        #expect(result.records[0][0] as? Int64 == 12)
        #expect(result.records[0][1] as? Int64 == 9_000_000_000)
        #expect(result.records[0][2] as? String == "first")
        #expect(result.records[0][3] as? Data == payload)
        #expect(result.records[0][4] as? Double == 1.5)
        let emptyValue: String? = result.records[0][5] as? String
        #expect(emptyValue == nil)
    }
}

@Test func executeReportsEffectsAndThrowsSQLiteErrors() async throws {
    try await withMemoryDatabase { database in
        try await database.execute(query: "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score REAL);")
        let insert = try await database.result(mapper: InsertUserMapper(id: 1, name: "Amina", score: 9.5, precompilation: .none))
        let update = try await database.result(mapper: InsertUserMapper(id: 2, name: "Omar", score: 7.0, precompilation: .named("insertUser")))

        #expect(insert.affected == 1)
        #expect(insert.lastInsertRowId == 1)
        #expect(update.affected == 1)
        #expect(update.lastInsertRowId == 2)

        var didThrowSQLiteError = false
        do {
            try await database.execute(query: "INSERT INTO missing_table VALUES (1);")
        } catch let SQLiteError.error(message) {
            didThrowSQLiteError = true
            #expect(message.isEmpty == false)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        #expect(didThrowSQLiteError)

        if case .error(let message) = await database.lastError() {
            #expect(message.isEmpty == false)
        }
    }
}

@Test func precompiledStatementsCanBeReusedWithDifferentBindings() async throws {
    try await withMemoryDatabase { database in
        try await database.execute {
            "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT);"
            "INSERT INTO users(id, name) VALUES (1, 'Amina'), (2, 'Omar');"
        }
        await database.precompile(name: "userById") {
            "SELECT name FROM users WHERE id = ?;"
        }

        let first = try await #require(database.result(precompiled: "userById", parameters: [.integer(1)]))
        let second = try await #require(database.result(precompiled: "userById", parameters: [.integer(2)]))
        let missing = try await database.result(precompiled: "missing", parameters: [])

        #expect(first.records.first?.first as? String == "Amina")
        #expect(second.records.first?.first as? String == "Omar")
        #expect(missing == nil)
    }
}

@Test func mapperReturnsRecordsScalarsAndReusesNamedStatement() async throws {
    try await withMemoryDatabase { database in
        try await database.execute {
            "CREATE TABLE users(id INTEGER PRIMARY KEY, name TEXT, score REAL);"
            "INSERT INTO users(id, name, score) VALUES (1, 'Amina', 9.5), (2, 'Omar', 7.0), (3, 'Noor', 8.25);"
        }

        let first = try await database.values(mapper: UsersByMinimumScoreMapper(minimumScore: 8))
        let second = try await database.values(mapper: UsersByMinimumScoreMapper(minimumScore: 9))
        let count = try await database.scalar(mapper: UserCountMapper())
        let resultSet = try await database.result(mapper: UserCountMapper())

        #expect(first == [
            UserRecord(id: 1, name: "Amina", score: 9.5),
            UserRecord(id: 3, name: "Noor", score: 8.25)
        ])
        #expect(second == [UserRecord(id: 1, name: "Amina", score: 9.5)])
        #expect(count == CountRecord(value: 3))
        #expect(resultSet.values == [CountRecord(value: 3)])
        #expect(resultSet.affected >= 0)
    }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 1.0, *)
@Test func sculGeneratesPositiveMonotonicIdentifiersWithBothConflictStrategies() async {
    let scul = Scul()
    let first = await scul.generate()
    let second = await scul.generate(resolve: .increment)
    let third = await scul.generate(resolve: .waiting)

    #expect(first > 0)
    #expect(second > first)
    #expect(third > second)
}
