# SQLiteKit

SQLiteKit is a SQLite-first Swift package that keeps SQL visible while adding Swift conveniences for actor-isolated database access, prepared statements, schema synchronization, row mapping, metadata inspection, and SCUL identifiers.


## Documentation

The package includes a Swift-DocC catalog at `Sources/SQLiteKit/SQLiteKit.docc` with guides, examples, best practices, and a tutorial. In Xcode, choose **Product > Build Documentation** to view it.

The documentation is hosted on [docs.iteam.studio](https://docs.iteam.studio), iTeam's documentation website for published package and API references. The SQLiteKit documentation is available directly at [docs.iteam.studio/docc/documentation/sqlitekit](https://docs.iteam.studio/docc/documentation/sqlitekit).

## Quick Example

```swift
import SQLiteKit

let database = try SQLiteDatabase(path: ":memory:")

try await database.schema {
    Table(name: "users")
        .column(name: "id", type: "INTEGER", notNull: true)
        .column(name: "name", type: "TEXT", notNull: true)
        .primaryKey(name: "pk_users", columns: ["id"])
}

let insert = PreparedStatement(
    query: "INSERT INTO users(id, name) VALUES (?, ?)",
    parameters: [.integer(1), .text("Aisha")]
)

_ = try await database.result(parepared: insert)

let users = try await database.result(
    header: true,
    parepared: PreparedStatement(query: "SELECT id, name FROM users")
)

await database.close()
```

