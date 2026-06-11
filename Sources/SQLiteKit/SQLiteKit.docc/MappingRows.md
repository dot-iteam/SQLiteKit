# Mapping Rows

Map SQLite result rows into explicit Swift values without reflection.

## RowMapper

Types that conform to ``RowMapper`` receive values by column index:

```swift
struct User: RowMapper {
    var id: Int64 = 0
    var name: String = ""

    mutating func set(value: Sendable?, at index: Int) {
        switch index {
        case 0:
            id = value as? Int64 ?? 0
        case 1:
            name = value as? String ?? ""
        default:
            break
        }
    }
}
```

The mapping order must match the `SELECT` list.

## QueryResultMapper

Create a mapper for a row-producing query:

```swift
struct UserListMapper: QueryResultMapper {
    let precompilation: Precompilation = .named("users.list")
    let query = "SELECT id, name FROM users ORDER BY name"
    let parameters: [SQLParameter] = []

    func newRecord() -> User {
        User()
    }
}
```

Execute the mapper with ``SQLiteDatabase/values(mapper:)``:

```swift
let users = try await database.values(mapper: UserListMapper())
```

Use ``SQLiteDatabase/scalar(mapper:)`` when only the first mapped row matters:

```swift
let first = try await database.scalar(mapper: UserListMapper())
```

## Parameterized Mappers

Mappers can store query parameters:

```swift
struct UserByIDMapper: QueryResultMapper {
    let id: Int64
    let precompilation: Precompilation = .named("users.byID")
    let query = "SELECT id, name FROM users WHERE id = ?"

    var parameters: [SQLParameter] {
        [.integer(id)]
    }

    func newRecord() -> User {
        User()
    }
}
```

```swift
let user = try await database.scalar(mapper: UserByIDMapper(id: 42))
```

## QueryMapper

Use ``QueryMapper`` for statements that produce effects instead of mapped rows:

```swift
struct RenameUserMapper: QueryMapper {
    let id: Int64
    let name: String
    let precompilation: Precompilation = .named("users.rename")
    let query = "UPDATE users SET name = ? WHERE id = ?"

    var parameters: [SQLParameter] {
        [.text(name), .integer(id)]
    }
}
```

```swift
let effect = try await database.result(
    mapper: RenameUserMapper(id: 42, name: "Fatima")
)

print(effect.affected)
```

## Choosing a Mapping Style

Use raw ``SQLResult`` when exploring, debugging, or building generic database tools.

Use mapper protocols for application code where you know the row shape and want compile-time Swift types.
