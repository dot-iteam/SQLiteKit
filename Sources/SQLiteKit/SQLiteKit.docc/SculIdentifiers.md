# Scul Identifiers

Generate compact, time-derived `Int64` identifiers for SQLite rows.

## Overview

``Scul`` is an actor that generates monotonic identifiers from UTC date components. The name means "Small-sCale-Unique-Long Identifier".

Use SCUL identifiers when you want an integer primary key that is generated in Swift and generally sorts by creation time.

```swift
let scul = Scul()
let id = await scul.generate()
```

``Scul`` is available on macOS 15, iOS 18, watchOS 11, tvOS 18, visionOS 1, and newer versions.

## Use With a Table

Declare an integer primary key:

```swift
try await database.schema {
    Table(name: "events")
        .column(name: "id", type: "INTEGER", notNull: true)
        .column(name: "name", type: "TEXT", notNull: true)
        .primaryKey(name: "pk_events", columns: ["id"])
}
```

Generate and insert an ID:

```swift
let scul = Scul()
let id = await scul.generate()

let insert = PreparedStatement(
    query: "INSERT INTO events(id, name) VALUES (?, ?)",
    parameters: [.integer(id), .text("Launch")]
)

_ = try await database.result(parepared: insert)
```

## Conflict Resolution

If the current time-derived value is not greater than the previous generated value, ``Scul`` resolves the collision with ``SculConflictResolution``.

The default is ``SculConflictResolution/increment``:

```swift
let id = await scul.generate(resolve: .increment)
```

This returns the previous identifier plus one.

Use ``SculConflictResolution/waiting`` to wait until the time-derived identifier space advances:

```swift
let id = await scul.generate(resolve: .waiting)
```

## Process Scope

SCUL tracks the last generated value in process memory. If multiple processes write to the same database, enforce uniqueness with a SQLite primary key or unique constraint and handle insert conflicts.
