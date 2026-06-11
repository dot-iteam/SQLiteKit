# Getting Started

Open a SQLite database, declare a schema, insert data, and read rows.

## Add SQLiteKit

Add the package to another Swift package or Xcode project and import the library target:

```swift
import SQLiteKit
```

SQLiteKit supports macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, and newer platform versions declared by the package.

## Open a Database

Create a ``SQLiteDatabase`` with a file path:

```swift
let database = try SQLiteDatabase(path: "/tmp/app.sqlite")
```

For temporary or unit-test use, open an in-memory database:

```swift
let database = try SQLiteDatabase(path: ":memory:")
```

During initialization SQLiteKit configures the connection with these defaults:

- `PRAGMA foreign_keys = ON`
- `PRAGMA journal_mode = WAL`
- `PRAGMA synchronous = NORMAL`
- `PRAGMA temp_store = MEMORY`

You can tune the connection at open time:

```swift
let database = try SQLiteDatabase(
    path: "/tmp/app.sqlite",
    tempStore: .memory,
    synchronous: .full,
    cacheSize: -20_000,
    mmapSize: 256 * 1024 * 1024
)
```

SQLite follows `PRAGMA cache_size` semantics. A positive `cacheSize` is interpreted as a number of database pages. A negative `cacheSize` is interpreted as an approximate size in kibibytes, so `-20_000` requests about 20,000 KiB of page cache.

## Actor Isolation

``SQLiteDatabase`` is an actor. Calls from outside the actor use `await`:

```swift
try await database.execute {
    "CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT NOT NULL);"
}
```

Actor isolation serializes access to the underlying SQLite connection.

## Create a Schema

Use ``SQLiteDatabase/schema(mode:entities:)`` to declare the desired schema:

```swift
try await database.schema {
    Table(name: "users")
        .column(name: "id", type: "INTEGER", notNull: true)
        .column(name: "name", type: "TEXT", notNull: true)
        .column(name: "created_at", type: "TEXT", defaultValue: "CURRENT_TIMESTAMP")
        .primaryKey(name: "pk_users", columns: ["id"])
        .index(name: "idx_users_name", columns: ["name"])
}
```

If a table is missing, SQLiteKit creates it. If a supported schema difference is detected, SQLiteKit rebuilds the table and copies data into the replacement table.

## Insert Data

Use raw SQL for trusted statements:

```swift
try await database.execute {
    "INSERT INTO users(id, name) VALUES (1, 'Aisha');"
}
```

Use ``PreparedStatement`` and ``SQLParameter`` for values that come from users or external systems:

```swift
let insert = PreparedStatement(
    query: "INSERT INTO users(id, name) VALUES (?, ?)",
    parameters: [.integer(2), .text("Omar")]
)

_ = try await database.result(parepared: insert)
```

## Query Rows

Request headers when you want column names:

```swift
let users = try await database.result(
    header: true,
    parepared: PreparedStatement(
        query: "SELECT id, name FROM users ORDER BY name"
    )
)

for row in users?.records ?? [] {
    print(row)
}
```

## Close the Connection

Call ``SQLiteDatabase/close()`` when the database is no longer needed:

```swift
await database.close()
```

Closing finalizes all precompiled statements before closing the SQLite connection.
