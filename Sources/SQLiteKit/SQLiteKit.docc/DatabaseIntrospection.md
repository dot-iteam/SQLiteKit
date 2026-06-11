# Database Introspection

Inspect SQLite schema metadata from the database actor.

## List Schema Entities

Use ``SQLiteDatabase/entities(type:)`` to list entries in `sqlite_schema`:

```swift
let allEntities = try await database.entities()
let tables = try await database.entities(type: .table)
let views = try await database.entities(type: .view)
```

Each ``EntityInfo`` contains the entity name, type, and stored SQL text when SQLite provides it.

## Check Existence

Check whether a table exists:

```swift
let hasUsers = try await database.exist(table: "users")
```

Check whether a column exists:

```swift
let hasEmail = try await database.exist(table: "users", column: "email")
```

## Inspect Columns

Use ``SQLiteDatabase/columns(table:)`` to inspect columns:

```swift
let columns = try await database.columns(table: "users")
```

Use ``SQLiteDatabase/info(table:column:)`` for a single column:

```swift
let email = try await database.info(table: "users", column: "email")
```

Column metadata is based on SQLite's `pragma_table_xinfo`.

## Inspect Keys and Constraints

Read foreign keys:

```swift
let foreignKeys = try await database.foreignKeys(table: "posts")
```

Look up one expected relationship:

```swift
let relation = try await database.info(
    table: "posts",
    foreignKey: ["user_id"],
    references: "users",
    on: ["id"]
)
```

Read unique constraints:

```swift
let uniqueConstraints = try await database.uniqueConstraints(table: "users")
let uniqueColumnSets = try await database.uniqueColumns(table: "users")
```

Read check expressions:

```swift
let checks = try await database.checkExpressions(table: "accounts")
```

## Inspect Indexes

Use ``SQLiteDatabase/info(table:index:origin:)`` to inspect a named index:

```swift
let index = try await database.info(
    table: "users",
    index: "idx_users_email"
)
```

SQLiteKit uses SQLite's index origin values. The default origin `c` means a created index. Use `u` for unique-constraint indexes.

## Inspect Views and Triggers

Read view metadata:

```swift
let view = try await database.info(view: "published_posts")
```

Read trigger metadata:

```swift
let trigger = try await database.info(trigger: "trg_posts_updated_at")
```

SQLiteKit uses these APIs internally to decide when views and triggers need to be recreated.

## Trusted Names

Introspection APIs interpolate table, column, index, view, and trigger names into SQLite metadata queries. Pass trusted schema names from your application code.
