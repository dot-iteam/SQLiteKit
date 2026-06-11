# Schema Management

Declare SQLite schema objects in Swift and let SQLiteKit create or synchronize them.

## Declare Tables

``Table`` is the primary schema declaration type:

```swift
Table(name: "users")
    .column(name: "id", type: "INTEGER", notNull: true)
    .column(name: "email", type: "TEXT", notNull: true)
    .column(name: "display_name", type: "TEXT")
    .primaryKey(name: "pk_users", columns: ["id"])
    .unique(name: "uq_users_email", columns: ["email"])
```

Pass declarations to ``SQLiteDatabase/schema(mode:entities:)``:

```swift
try await database.schema {
    Table(name: "users")
        .column(name: "id", type: "INTEGER", notNull: true)
        .column(name: "email", type: "TEXT", notNull: true)
        .primaryKey(name: "pk_users", columns: ["id"])
}
```

## Columns

Create columns with a SQLite type declaration:

```swift
.column(name: "created_at", type: "TEXT", defaultValue: "CURRENT_TIMESTAMP")
```

Use `notNull` for `NOT NULL` columns:

```swift
.column(name: "title", type: "TEXT", notNull: true)
```

Use the `modify` closure for column modifiers:

```swift
.column(name: "name_normalized", type: "TEXT") { column in
    column.generation(.stored("lower(name)"))
}
```

Generated columns use ``ColumnGeneration``:

```swift
Column(name: "search_key", type: "TEXT")
    .generation(.virtual("lower(title)"))
```

## Primary Keys

Add a table-level primary key with ``Table/primaryKey(name:columns:)``:

```swift
Table(name: "documents")
    .column(name: "id", type: "INTEGER", notNull: true)
    .primaryKey(name: "pk_documents", columns: ["id"])
```

SQLiteKit emits a named table constraint:

```sql
CONSTRAINT [pk_documents] PRIMARY KEY ([id])
```

## Foreign Keys

Declare relationships with ``Table/foreignKey(name:columns:references:on:)``:

```swift
Table(name: "posts")
    .column(name: "id", type: "INTEGER", notNull: true)
    .column(name: "user_id", type: "INTEGER", notNull: true)
    .primaryKey(name: "pk_posts", columns: ["id"])
    .foreignKey(
        name: "fk_posts_users",
        columns: ["user_id"],
        references: "users",
        on: ["id"]
    )
```

SQLiteKit enables foreign keys when opening the database.

## Unique Constraints

Declare a unique constraint with ``Table/unique(name:columns:)``:

```swift
Table(name: "users")
    .column(name: "email", type: "TEXT", notNull: true)
    .unique(name: "uq_users_email", columns: ["email"])
```

## Checks

Use raw expressions or SQL fragments for `CHECK` constraints:

```swift
Table(name: "accounts")
    .column(name: "balance", type: "REAL", notNull: true, defaultValue: "0")
    .check("balance >= 0")
```

```swift
Table(name: "ratings")
    .column(name: "score", type: "INTEGER", notNull: true)
    .check {
        "score >= 1 AND score <= 5"
    }
```

## Indexes

Create an index inside the table declaration:

```swift
Table(name: "posts")
    .column(name: "created_at", type: "TEXT", notNull: true)
    .index(name: "idx_posts_created_at", columns: ["created_at"])
```

Or create one as a standalone schema entity:

```swift
Index(
    name: "idx_posts_title",
    table: "posts",
    columns: ["title"]
)
```

Use `unique: true` for a unique index.

## Views

Declare a view with ``View``:

```swift
View(name: "published_posts") {
    "CREATE VIEW [published_posts] AS"
    "SELECT id, title, created_at FROM posts WHERE published = 1;"
}
```

SQLiteKit compares the stored SQL text and recreates the view when the definition changes.

## Triggers

Declare a trigger with ``Trigger``:

```swift
Trigger(name: "trg_posts_updated_at") {
    "CREATE TRIGGER [trg_posts_updated_at]"
    "AFTER UPDATE ON [posts]"
    "BEGIN"
    "UPDATE posts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;"
    "END;"
}
```

SQLiteKit compares the stored SQL text and recreates the trigger when the definition changes.

## Synchronization Modes

``SchemaMatchMode/strict`` compares supported constraints as exact sets. Use it when the declared schema should be authoritative.

```swift
try await database.schema(mode: .strict) {
    // schema declarations
}
```

``SchemaMatchMode/flexible`` checks requested relationships and unique constraints individually. Use it when existing compatible schema details may be broader than the declarations.

```swift
try await database.schema(mode: .flexible) {
    // schema declarations
}
```

## Migration Behavior

When SQLiteKit detects a supported table shape change, it:

1. Disables foreign keys.
2. Begins a transaction.
3. Creates a replacement table.
4. Copies non-generated columns from the old table.
5. Drops the old table.
6. Renames the replacement table.
7. Commits and re-enables foreign keys.

Review generated SQL and test migrations with representative data before shipping schema changes.
