//
//  Scheme.swift
//  SQLiteKit
//
//  Created by Dot iTeam on 2026-05-31.
//

/// A value that can participate in SQLiteKit schema synchronization.
public protocol SchemaEntity {
    
}
/// Builds a list of schema entities.
@resultBuilder
public struct SchemeBuilder {
    /// Combines schema entities into an ordered list.
    public static func buildBlock(_ components: SchemaEntity...) -> [SchemaEntity] {
        components
    }
    
}
/// Sort order for a named column in an index or constraint.
public enum Order: String, Sendable {
    /// Ascending order.
    case asc = "ASC"
    /// Descending order.
    case desc = "DESC"
}
/// A table declaration used by SQLiteKit's schema synchronizer.
public struct Table : Sendable, SchemaEntity {
    /// The table name.
    public let name: String
    /// Columns declared on the table.
    public var columns: [Column]
    /// Optional primary key constraint.
    public var primaryKey: PrimaryKey?
    /// Foreign key constraints declared on the table.
    public var foreignKeys: [ForeignKey]
    /// Indexes associated with the table.
    public var indices: [Index]
    /// Unique constraints declared on the table.
    public var uniqueConstraints: [UniqueConstraint]
    /// Check constraint expressions declared on the table.
    public var checks: [String]
    /// Creates an empty table declaration.
    public init(name: String) {
        self.name = name
        self.columns = []
        self.foreignKeys = []
        self.uniqueConstraints = []
        self.checks = []
        self.primaryKey = nil
        self.indices = []
    }
    /// Creates a `CREATE TABLE` statement for the supplied table components.
    public static func creationStatement(
        name: String,
        columns: [Column],
        primaryKey: PrimaryKey?,
        foreignKeys: [ForeignKey],
        uniqueConstraints: [UniqueConstraint],
        checks: [String]) -> String {
            var statements: [String] = []
            
            statements.append(contentsOf: columns.map(\.description))
            if let pk = primaryKey {
                statements.append(pk.description)
            }
            statements.append(contentsOf: foreignKeys.map(\.description))
            statements.append(contentsOf: uniqueConstraints.map(\.description))
            statements.append(contentsOf: checks.map { ck in "CHECK (\(ck))"})
            return "CREATE TABLE [\(name)](\(statements.joined(separator: ",")));"
    }
    /// Returns a copy of the table with an additional column.
    ///
    /// - Parameters:
    ///   - name: Column name.
    ///   - type: SQLite column type declaration.
    ///   - notNull: Whether the column should include `NOT NULL`.
    ///   - defaultValue: Optional SQL default expression.
    ///   - modify: Optional closure for applying column modifiers such as
    ///     generated-column metadata.
    public func column(name: String, type: String, notNull: Bool = false, defaultValue: String? = nil, modify: ((Column) -> Column)? = nil) -> Self {
        var this = self
        var col = Column(
            name: name,
            type: type,
            notNull: notNull,
            defaultValue: defaultValue
        )
        if let modify {
            col =  modify(col)
        }
        this.columns.append(col)
        return this
    }
    /// Returns a copy of the table with a primary key constraint.
    public func primaryKey(name: String, columns: [String]) -> Self {
        var this = self
        this.primaryKey = .init(name: name, columns: columns)
        return this
    }
    /// Returns a copy of the table with a foreign key constraint.
    public func foreignKey(name: String, columns: [String], references table: String, on: [String]) -> Self {
        var this = self
        this.foreignKeys.append(.init(name: name, columns: columns, reference: table, on: on))
        return this
    }
    /// Returns a copy of the table with an associated index.
    public func index(name: String, columns: [NamedColumnProtocol], unique: Bool = false) -> Self {
        var this = self
        this.indices.append(.init(name: name, table: self.name, columns: columns, unique: unique))
        return this
    }
    /// Returns a copy of the table with a unique constraint.
    public func unique(name: String, columns: [String]) -> Self {
        var this = self
        this.uniqueConstraints.append(.init(name: name, columns: columns))
        return this
    }
    /// Returns a copy of the table with a `CHECK` constraint expression.
    public func check(_ check: String) -> Self {
        var this = self
        this.checks.append(check)
        return this
    }
    /// Returns a copy of the table with a `CHECK` constraint built from SQL fragments.
    public func check(@QueryBuilder _ check: () -> SQLQuery) -> Table {
        self.check(check().sql)
    }
}
/// A table primary key constraint.
public struct PrimaryKey: Sendable, CustomStringConvertible {
    /// The constraint name.
    public let name: String
    /// Columns included in the primary key.
    public let columns: [NamedColumnProtocol]
    /// Optional ordering metadata.
    public var order: [String] = []
    /// SQL text for the primary key constraint.
    public var description: String {
        "CONSTRAINT [\(name)] PRIMARY KEY (\(columns.map(\.sqlName).joined(separator: ",")))"
    }
    /// Returns a copy with ordering metadata.
    public func order(_ order: String...) -> Self {
        var this = self
        this.order = order
        return this
    }
}
/// A type that can provide a SQLite column name expression.
public protocol NamedColumnProtocol: Sendable {
    /// The unquoted column name.
    var name : String { get }
    /// The SQL column expression.
    var sqlName: String { get }
}
/// A named column with an ordering annotation.
public struct OrderedColumn: NamedColumnProtocol {
    /// The unquoted column name.
    public let name: String
    /// The ordering applied to the column.
    public let order: Order = .asc
    /// The SQL column expression.
    public var sqlName: String {
        "[\(name)] \(order.rawValue)"
    }
}
extension String: NamedColumnProtocol {
    /// The string as an unquoted column name.
    public var name : String { self }
    /// The string wrapped as a SQLite identifier.
    public var sqlName: String { "[\(self)]" }
}
/// Defines a generated column expression.
public enum ColumnGeneration: Sendable, CustomStringConvertible {
    /// A virtual generated column.
    case virtual(String)
    /// A stored generated column.
    case stored(String)
    /// SQL text for the generated column clause.
    public var description: String {
        return switch self {
        case .virtual(let value):
            "GENERATED ALWAYS AS (\(value)) VIRTUAL"
        case .stored(let value):
            "GENERATED ALWAYS AS (\(value)) STORED"
        }
        
    }
}
/// A table column declaration.
public struct Column: Sendable, CustomStringConvertible {
    /// SQL text for the column declaration.
    public var description: String {
        sql(
            "[\(name)] \(type)",
            isNotNull ? " NOT NULL" : "",
            defaultValue != nil ? " DEFAULT \(defaultValue!)" : "",
            generation != nil ? " \(generation!.description)" : ""
        ).sql
    }
    /// The column name.
    public let name: String
    /// The SQLite column type declaration.
    public let type: String
    var isNotNull: Bool = false
    var defaultValue: String?
    var generation: ColumnGeneration?
    /// Creates a column declaration.
    public init (name: String, type: String, notNull: Bool = false, defaultValue: String? = nil) {
        self.name = name
        self.type = type
        self.isNotNull = notNull
        self.defaultValue = defaultValue
    }
    /// Returns a copy configured as a generated column.
    public func generation(_ generation: ColumnGeneration) -> Column {
        var this = self
        this.generation = generation
        return this
    }
}
/// A table foreign key constraint.
public struct ForeignKey : Sendable, CustomStringConvertible {
    /// The constraint name.
    public let name: String
    /// Local columns participating in the relationship.
    public let columns: [String]
    /// Referenced table name.
    public let reference: String
    /// Referenced columns.
    public let on: [String]
    /// SQL text for the foreign key constraint.
    public var description: String {
        "CONSTRAINT \(name) FOREIGN KEY (\(columns.map { "[\($0)]" }.joined(separator: ","))) REFERENCES \(reference)(\(on.map { "[\($0)]" }.joined(separator: ",")))"
    }
}
/// A table unique constraint.
public struct UniqueConstraint : Sendable, CustomStringConvertible {
    /// The constraint name.
    public let name: String
    /// Columns included in the unique constraint.
    public let columns: [NamedColumnProtocol]
    /// SQL text for the unique constraint.
    public var description: String {
        "CONSTRAINT [\(name)] UNIQUE(\(columns.map(\.sqlName).joined(separator: ",")))"
    }
}

/// An index declaration.
public struct Index : Sendable, CustomStringConvertible, SchemaEntity {
    /// The index name.
    public let name: String
    /// The indexed table name.
    public let table: String
    /// Indexed columns.
    public let columns: [NamedColumnProtocol]
    /// Whether the index is unique.
    public let unique: Bool
    /// Creates an index declaration.
    public init(name: String, table: String, columns: [NamedColumnProtocol], unique: Bool = false) {
        self.name = name
        self.table = table
        self.columns = columns
        self.unique = unique
    }
    /// SQL text for creating the index.
    public var description: String {
        "CREATE\(unique ? " UNIQUE" : "") INDEX [\(name)] ON [\(table)](\(columns.map(\.sqlName).joined(separator: ",")))"
    }
}
/// A view declaration.
public struct View: Sendable, CustomStringConvertible, SchemaEntity {
    /// The view name.
    public let name: String
    /// SQL text that creates the view.
    public let sql: String
    /// Creates a view declaration from SQL fragments.
    public init(name: String, @QueryBuilder query: () -> SQLQuery) {
        self.name = name
        self.sql = query().sql
    }
    /// SQL text that creates the view.
    public var description: String {
        sql
    }
}
/// A trigger declaration.
public struct Trigger: Sendable, CustomStringConvertible, SchemaEntity {
    /// The trigger name.
    public let name: String
    /// SQL text that creates the trigger.
    public let sql: String
    /// Creates a trigger declaration from SQL fragments.
    public init(name: String, @QueryBuilder query: () -> SQLQuery) {
        self.name = name
        self.sql = query().sql
    }
    /// SQL text that creates the trigger.
    public var description: String {
        sql
    }
}
