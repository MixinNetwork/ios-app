import Foundation
import GRDB

open class Database {
    
    public typealias UniqueStringPairs = [String: String]
    public typealias Completion = ((GRDB.Database) -> Void)
    
    open class var config: Configuration {
        var config = Configuration()
        config.prepareDatabase { (db) in
            db.trace(options: .profile) { (event) in
                guard case let .profile(statement, duration) = event else {
                    return
                }
                if duration > 1 {
                    Logger.writeDatabase(log: "[DB][Performance]SQL: \(statement.sql)")
                    Logger.writeDatabase(log: "[DB][Performance]Total cost \(duration)s", newSection: true)
                }
            }
        }
        return config
    }
    
    private static let registerErrorLogFunction: () -> Void = {
        struct Error: Swift.Error {
            let code: CInt
            let message: String
        }
        GRDB.Database.logError = { (code, message) in
            guard code.primaryResultCode != .SQLITE_NOTICE else {
                return
            }
            if code.primaryResultCode == .SQLITE_ERROR {
                if message.hasPrefix("no such table: grdb_migrations") {
                    return
                } else {
                    AppGroupUserDefaults.User.needsRebuildDatabase = true
                }
            }
            reporter.report(error: Error(code: code.rawValue, message: message))
            Logger.writeDatabase(log: "[DB] Error: \(code), \(message)", newSection: true)
        }
        return {}
    }()
    
    open var needsMigration: Bool {
        false
    }
    
    public let pool: DatabasePool
    
    public init(url: URL) throws {
        Self.registerErrorLogFunction()
        pool = try DatabasePool(path: url.path, configuration: Self.config)
    }
    
    @discardableResult
    public func write(_ updates: (GRDB.Database) throws -> Void) -> Bool {
        do {
            try pool.write(updates)
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    public func execute(
        sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> Bool {
        write { (db) in
            try db.execute(sql: sql, arguments: arguments)
        }
    }
    
    // Only use for migration. See comments in *ColumnMigratableTableDefinition*
    internal func migrateTable(
        with table: ColumnMigratable,
        into db: GRDB.Database
    ) throws {
        if try db.tableExists(table.tableName) {
            let existedColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(\(table.tableName.quotedDatabaseIdentifier));")
            let existedColumnNames = Set(existedColumns.map(\.name))
            if let sql = table.alterTableSQL(existedColumnNames: existedColumnNames) {
                try db.execute(sql: sql)
            }
        } else {
            try db.execute(sql: table.createTableSQL())
        }
    }
    
}

// MARK: - Metadata Fetching
extension Database {
    
    public func recordExists<Record: TableRecord>(
        in table: Record.Type,
        where condition: SQLSpecificExpressible
    ) -> Bool {
        try! pool.read { (db) -> Bool in
            try table.select(Column.rowID).filter(condition).fetchOne(db) != nil
        }
    }
    
    public func count<Record: TableRecord>(
        in table: Record.Type,
        where condition: SQLSpecificExpressible? = nil
    ) -> Int {
        try! pool.read({ (db) -> Int in
            if let condition = condition {
                return try table.filter(condition).fetchCount(db)
            } else {
                return try table.fetchCount(db)
            }
        })
    }
    
}

// MARK: - Record Fetching
extension Database {
    
    public func selectAll<Record: MixinFetchableRecord & TableRecord>() -> [Record] {
        try! pool.read { (db) -> [Record] in
            try Record.fetchAll(db)
        }
    }
    
    public func select<Value: DatabaseValueConvertible>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> Value? {
        try! pool.read({ (db) -> Value? in
            try Value.fetchOne(db, sql: sql, arguments: arguments, adapter: nil)
        })
    }
    
    public func select<Value: DatabaseValueConvertible>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> [Value] {
        try! pool.read({ (db) -> [Value] in
            let values = try Value?.fetchAll(db, sql: sql, arguments: arguments, adapter: nil)
            return values.compactMap { $0 }
        })
    }
    
    public func select<Record: TableRecord, Value: DatabaseValueConvertible>(
        column: Column,
        from table: Record.Type,
        where condition: SQLSpecificExpressible? = nil
    ) -> Value? {
        try! pool.read { (db) -> Value? in
            var request = Record.select([column])
            if let condition = condition {
                request = request.filter(condition)
            }
            return try Value.fetchOne(db, request)
        }
    }
    
    public func select<Record: TableRecord, Value: DatabaseValueConvertible>(
        column: Column,
        from table: Record.Type,
        where condition: SQLSpecificExpressible? = nil,
        order orderings: [SQLOrderingTerm]? = nil,
        offset: Int? = nil,
        limit: Int? = nil
    ) -> [Value] {
        try! pool.read { (db) -> [Value] in
            var request = Record.select([column])
            if let condition = condition {
                request = request.filter(condition)
            }
            if let orderings = orderings {
                request = request.order(orderings)
            }
            if let limit = limit {
                request = request.limit(limit, offset: offset)
            }
            let values = try Value?.fetchAll(db, request)
            return values.compactMap { $0 }
        }
    }
    
    public func select<Table: TableRecord>(
        keyColumn: Column,
        valueColumn: Column,
        from table: Table.Type,
        where condition: SQLSpecificExpressible? = nil,
        order orderings: [SQLOrderingTerm]? = nil,
        offset: Int? = nil,
        limit: Int? = nil
    ) -> UniqueStringPairs {
        try! pool.read { (db) -> UniqueStringPairs in
            var pairs = UniqueStringPairs()
            var request = table.select([keyColumn, valueColumn])
            if let condition = condition {
                request = request.filter(condition)
            }
            if let orderings = orderings {
                request = request.order(orderings)
            }
            if let limit = limit {
                request = request.limit(limit, offset: offset)
            }
            let rows = try Row.fetchCursor(db, request)
            while let row = try rows.next() {
                guard let key: UniqueStringPairs.Key = row[keyColumn.name] else {
                    continue
                }
                pairs[key] = row[valueColumn.name]
            }
            return pairs
        }
    }
    
    public func select<Record: MixinFetchableRecord & TableRecord>(
        where condition: SQLSpecificExpressible,
        order orderings: [SQLOrderingTerm] = []
    ) -> Record? {
        try! pool.read { (db) -> Record? in
            try Record.filter(condition)
                .order(orderings)
                .fetchOne(db)
        }
    }
    
    public func select<Record: MixinFetchableRecord & TableRecord>(
        where condition: SQLSpecificExpressible,
        order orderings: [SQLOrderingTerm] = [],
        limit: Int? = nil
    ) -> [Record] {
        try! pool.read { (db) -> [Record] in
            var request = Record.filter(condition)
            if !orderings.isEmpty {
                request = request.order(orderings)
            }
            if let limit = limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }
    
    public func select<Record: MixinFetchableRecord>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> Record? {
        try! pool.read { (db) -> Record? in
            try Record.fetchOne(db, sql: sql, arguments: arguments, adapter: nil)
        }
    }
    
    public func select<Record: MixinFetchableRecord>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> [Record] {
        try! pool.read { (db) -> [Record] in
            try Record.fetchAll(db, sql: sql, arguments: arguments, adapter: nil)
        }
    }
    
}

// MARK: - Record Writing
extension Database {
    
    // Returns true on success, false on transaction
    @discardableResult
    public func save<Record: PersistableRecord>(
        _ record: Record,
        completion: Completion? = nil
    ) -> Bool {
        write { (db) in
            try record.save(db)
            if let completion = completion {
                db.afterNextTransactionCommit(completion)
            }
        }
    }
    
    @discardableResult
    public func save<Record: PersistableRecord>(
        _ records: [Record],
        completion: Completion? = nil
    ) -> Bool {
        guard records.count > 0 else {
            return true
        }
        do {
            try pool.write { (db) -> Void in
                try records.save(db)
                if let completion = completion {
                    db.afterNextTransactionCommit(completion)
                }
            }
            return true
        } catch {
            return false
        }
    }
    
    // Returns true on success, false on transaction
    @discardableResult
    public func update<Record: PersistableRecord>(
        _ record: Record.Type,
        assignments: [ColumnAssignment],
        where condition: SQLSpecificExpressible,
        completion: Completion? = nil
    ) -> Bool {
        write { (db) in
            try record.filter(condition).updateAll(db, assignments)
            if let completion = completion {
                db.afterNextTransactionCommit(completion)
            }
        }
    }
    
}

// MARK: - Record Deletion
extension Database {
    
    @discardableResult
    public func delete<Record: PersistableRecord>(
        _ record: Record.Type,
        where condition: SQLSpecificExpressible,
        completion: Completion? = nil
    ) -> Int {
        do {
            var numberOfChanges = 0
            try pool.write({ (db) -> Void in
                numberOfChanges = try record.filter(condition).deleteAll(db)
                if let completion = completion {
                    db.afterNextTransactionCommit(completion)
                }
            })
            return numberOfChanges
        } catch {
            return 0
        }
    }
    
}
