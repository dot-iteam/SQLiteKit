# Executing SQL

Run SQL statements directly, compose SQL fragments with a result builder, and bind values through prepared statements.

## SQL Fragments

``String`` conforms to ``SQLQuery``, so a string can be executed directly:

```swift
try await database.execute(query: "DELETE FROM sessions;")
```

The ``QueryBuilder`` result builder lets you write multi-line SQL:

```swift
try await database.execute {
    "CREATE TABLE IF NOT EXISTS notes("
    "id INTEGER PRIMARY KEY,"
    "body TEXT NOT NULL"
    ");"
}
```

The builder joins each fragment with a newline. You can also compose smaller fragments with ``sql(separator:_:)``:

```swift
let tableName = "notes"
let statement = sql(
    "SELECT id, body FROM ",
    "[\(tableName)]",
    " ORDER BY id DESC;"
)
```

Use direct interpolation only for trusted identifiers or fixed SQL fragments.

## Prepared Statements

Use ``PreparedStatement`` when binding values:

```swift
let statement = PreparedStatement(
    query: "SELECT id, body FROM notes WHERE id = ?",
    parameters: [.integer(42)]
)

let result = try await database.result(header: true, parepared: statement)
```

Parameters are positional. The first ``SQLParameter`` binds to the first `?`, the second parameter binds to the second `?`, and so on.

## Supported Parameter Values

``SQLParameter`` supports SQLite's common storage classes:

```swift
[
    .text("hello"),
    .int(12),
    .integer(9_223_372_036_854_775_000),
    .real(3.14),
    .blob(Data([0x01, 0x02]))
]
```

## Reading Results

``SQLResult`` contains optional headers, row values, the affected row count, and the last insert row identifier:

```swift
if let result = try await database.result(header: true, parepared: statement) {
    print(result.header ?? [])
    print(result.records)
    print(result.affected)
    print(result.lastInsertRowId)
}
```

SQLiteKit converts SQLite columns into Swift values:

- `TEXT` becomes `String`.
- `INTEGER` becomes `Int64`.
- `FLOAT` becomes `Double`.
- `BLOB` becomes `Data`.
- `NULL` becomes `nil`.

## Statements Without Rows

Use ``SQLiteDatabase/execute(query:)`` or the query-builder overload for statements where you do not need result metadata:

```swift
try await database.execute {
    "UPDATE notes SET body = 'Updated' WHERE id = 42;"
}
```

Use ``SQLiteDatabase/result(header:parepared:)`` when you want `affected` or `lastInsertRowId` from an insert, update, or delete.

## Error Handling

SQLite errors are thrown as ``SQLiteError``:

```swift
do {
    try await database.execute(query: "SELECT * FROM missing_table;")
} catch SQLiteError.error(let message) {
    print(message)
}
```
