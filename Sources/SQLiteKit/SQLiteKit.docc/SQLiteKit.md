
# ``SQLiteKit``

Use SQLite directly from Swift with an actor-isolated database connection, prepared statements, schema synchronization, row mapping, and compact unique identifiers.

## Overview

SQLiteKit is a SQLite-first toolkit. It does not try to hide SQL behind an object-relational mapper. Instead, it keeps SQL visible while providing Swift conveniences around connection isolation, parameter binding, schema declarations, metadata inspection, and explicit row mapping.

The central type is ``SQLiteDatabase``. It opens a SQLite database, configures common pragmas, serializes access through Swift actor isolation, executes SQL, manages reusable prepared statements, and synchronizes schema entities.

Use SQLiteKit when you want:

- Direct control over SQL.
- Prepared statements with Swift value binding.
- A lightweight schema DSL for tables, constraints, indexes, views, and triggers.
- Explicit row mapping without reflection.
- Database metadata inspection.
- Time-derived SQLite-friendly identifiers with ``Scul``.

## Basic Example

```swift
import SQLiteKit

let database = try SQLiteDatabase(path: "/tmp/app.sqlite")

try await database.schema {
    Table(name: "users")
        .column(name: "id", type: "INTEGER", notNull: true)
        .column(name: "name", type: "TEXT", notNull: true)
        .primaryKey(name: "pk_users", columns: ["id"])
        .index(name: "idx_users_name", columns: ["name"])
}

try await database.execute {
    "INSERT INTO users(id, name) VALUES (1, 'Aisha');"
}

let result = try await database.result(
    header: true,
    parepared: PreparedStatement(
        query: "SELECT id, name FROM users WHERE id = ?",
        parameters: [.integer(1)]
    )
)

await database.close()
```

> Important: Use ``SQLParameter`` values for user-provided data. Schema identifiers and raw SQL fragments are inserted into SQL strings directly, so they should come from trusted code.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ExecutingSQL>
- <doc:SchemaManagement>
- <doc:MappingRows>

### Advanced Usage

- <doc:PrecompiledStatements>
- <doc:DatabaseIntrospection>
- <doc:SculIdentifiers>

### Database

- ``SQLiteDatabase``
- ``SQLiteError``
- ``SQLiteSynchronous``
- ``SQLiteTempStore``

### SQL Execution

- ``PreparedStatement``
- ``SQLParameter``
- ``SQLResult``
- ``SQLResultSet``
- ``SQLEffect``
- ``SQLQuery``
- ``QueryBuilder``
- ``sql(separator:_:)``

### Schema

- ``SchemaEntity``
- ``SchemeBuilder``
- ``SchemaMatchMode``
- ``Table``
- ``Column``
- ``ColumnGeneration``
- ``PrimaryKey``
- ``ForeignKey``
- ``UniqueConstraint``
- ``Index``
- ``View``
- ``Trigger``
- ``NamedColumnProtocol``
- ``OrderedColumn``
- ``Order``

### Mapping

- ``RowMapper``
- ``QueryMapper``
- ``QueryResultMapper``
- ``Precompilation``
- ``Row``

### Metadata

- ``EntityInfo``
- ``EntityType``
- ``ColumnInfo``
- ``PrimaryKeyInfo``
- ``ForeignKeyInfo``
- ``IndexInfo``
- ``ViewInfo``
- ``TriggerInfo``

### Identifiers

- ``Scul``
- ``SculConflictResolution``
