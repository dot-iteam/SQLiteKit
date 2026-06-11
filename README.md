# SQLiteKit

SQLiteKit is a SQLite-first Swift package that keeps SQL visible while adding Swift conveniences for actor-isolated database access, prepared statements, schema synchronization, row mapping, metadata inspection, and SCUL identifiers.

## Documentation

SQLiteKit includes a Swift-DocC documentation catalog at:

```text
Sources/SQLiteKit/SQLiteKit.docc
```

OR hosted version

[SQLiteKit Documentation](https://docs.iteam.studio/docc/documentation/sqlitekit)

GitHub can display the Markdown files in this catalog, but it does not automatically build Swift-DocC documentation or resolve DocC-specific symbol links and article links such as ``SQLiteDatabase`` or `<doc:GettingStarted>`. To read the documentation as intended, open the package in Xcode and use Xcode's documentation catalog reader / documentation viewer.

In Xcode, select the `SQLiteKit.docc` catalog or build documentation for the package to browse the rendered articles, tutorials, and API reference with internal links resolved.

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

