# Precompiled Statements

Reuse SQLite prepared statements for repeated queries.

## Why Precompile

Preparing SQL has a cost. For statements that run often, precompile once and execute the named statement with different parameters.

SQLiteKit supports two precompilation styles:

- Manual precompilation with ``SQLiteDatabase/precompile(name:query:)``.
- Mapper-driven precompilation with ``Precompilation/named(_:)``.

## Manual Precompilation

Prepare a statement and store it by name:

```swift
await database.precompile(
    name: "users.byID",
    query: "SELECT id, name FROM users WHERE id = ?"
)
```

Execute it by name:

```swift
let result = try await database.result(
    header: true,
    precompiled: "users.byID",
    parameters: [.integer(42)]
)
```

SQLiteKit resets the statement and clears bindings after each execution.

## Builder-Based Precompilation

Use the query builder overload for multi-line SQL:

```swift
await database.precompile(name: "posts.recent") {
    "SELECT id, title, created_at"
    "FROM posts"
    "WHERE published = ?"
    "ORDER BY created_at DESC"
    "LIMIT ?"
}
```

```swift
let result = try await database.result(
    precompiled: "posts.recent",
    parameters: [.integer(1), .integer(20)]
)
```

## Mapper Precompilation

Mappers can request automatic named precompilation:

```swift
struct RecentPostsMapper: QueryResultMapper {
    let limit: Int64
    let precompilation: Precompilation = .named("posts.recent")
    let query = """
        SELECT id, title
        FROM posts
        WHERE published = 1
        ORDER BY created_at DESC
        LIMIT ?
        """

    var parameters: [SQLParameter] {
        [.integer(limit)]
    }

    func newRecord() -> Post {
        Post()
    }
}
```

The first execution prepares the statement and stores it under the name. Later executions reuse it.

## Lifetime

Precompiled statements live until ``SQLiteDatabase/close()`` finalizes them or the database actor is discarded.

Choose stable names such as `users.byID`, `posts.recent`, or `settings.upsert` so related mapper types and manual calls do not accidentally collide.
