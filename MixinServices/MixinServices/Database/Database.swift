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
                    // Add a trailing linebreak to clear the border of SQL string
                    let message = """
                        Duration: \(duration)s, SQL:
                        \(statement.sql)
                        
                    """
                    Logger.database.info(category: "Trace", message: message)
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
            Logger.database.error(category: "Error", message: "code: \(code), message: \(message)\n")
        }
        return {}
    }()
    
    open var needsMigration: Bool {
        false
    }
    
    let pool: DatabasePool
    
    public init(url: URL) throws {
        Self.registerErrorLogFunction()
        pool = try DatabasePool(path: url.path, configuration: Self.config)
    }
    
    open func tableDidLose() {
        
    }
    
    public func read<Value>(_ reader: (GRDB.Database) throws -> Value) throws -> Value {
        do {
            return try pool.read(reader)
        } catch {
            markDatabaseNeedsRebuildIfNeeded(error: error)
            throw error
        }
    }
    
    @discardableResult
    public func write(_ updates: (GRDB.Database) throws -> Void) -> Bool {
        do {
            try pool.write(updates)
            return true
        } catch {
            markDatabaseNeedsRebuildIfNeeded(error: error)
            return false
        }
    }
    
    public func writeAndReturnError<Value>(_ updates: (GRDB.Database) throws -> Value) throws -> Value {
        do {
            return try pool.write(updates)
        } catch {
            markDatabaseNeedsRebuildIfNeeded(error: error)
            throw error
        }
    }
    
    public func vacuum() throws {
        try pool.vacuum()
    }
    
    public func makeSnapshot() throws -> DatabaseSnapshot {
        try pool.makeSnapshot()
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
    
    private func markDatabaseNeedsRebuildIfNeeded(error: Error) {
        guard let error = error as? GRDB.DatabaseError else {
            return
        }
        guard let message = error.message, message.hasPrefix("no such table:"), !message.hasPrefix("no such table: grdb_migrations") else {
            return
        }
        tableDidLose()
    }
    
}

// MARK: - Metadata Fetching
extension Database {
    
    public func recordExists<Record: TableRecord>(
        in table: Record.Type,
        where condition: SQLSpecificExpressible
    ) -> Bool {
        try! read { (db) -> Bool in
            try table.select(Column.rowID).filter(condition).fetchOne(db) != nil
        }
    }
    
    public func count<Record: TableRecord>(
        in table: Record.Type,
        where condition: SQLSpecificExpressible? = nil
    ) -> Int {
        try! read { (db) -> Int in
            if let condition = condition {
                return try table.filter(condition).fetchCount(db)
            } else {
                return try table.fetchCount(db)
            }
        }
    }
    
}

// MARK: - Record Fetching
extension Database {
    
    public func selectAll<Record: MixinFetchableRecord & TableRecord>() -> [Record] {
        try! read { (db) -> [Record] in
            try Record.fetchAll(db)
        }
    }
    
    public func select<Value: DatabaseValueConvertible>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> Value? {
        try! read { (db) -> Value? in
            try Value.fetchOne(db, sql: sql, arguments: arguments, adapter: nil)
        }
    }
    
    public func select<Value: DatabaseValueConvertible>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> [Value] {
        try! read { (db) -> [Value] in
            let values = try Value?.fetchAll(db, sql: sql, arguments: arguments, adapter: nil)
            return values.compactMap { $0 }
        }
    }
    
    public func select<Record: TableRecord, Value: DatabaseValueConvertible>(
        column: Column,
        from table: Record.Type,
        where condition: SQLSpecificExpressible? = nil
    ) -> Value? {
        try! read { (db) -> Value? in
            var request = Record.select([column]).limit(1)
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
        try! read { (db) -> [Value] in
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
        try! read { (db) -> UniqueStringPairs in
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
        try! read { (db) -> Record? in
            try Record.filter(condition)
                .order(orderings)
                .limit(1)
                .fetchOne(db)
        }
    }
    
    public func select<Record: MixinFetchableRecord & TableRecord>(
        where condition: SQLSpecificExpressible,
        order orderings: [SQLOrderingTerm] = [],
        limit: Int? = nil
    ) -> [Record] {
        try! read { (db) -> [Record] in
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
        try! read { (db) -> Record? in
            try Record.fetchOne(db, sql: sql, arguments: arguments, adapter: nil)
        }
    }
    
    public func select<Record: MixinFetchableRecord>(
        with sql: String,
        arguments: StatementArguments = StatementArguments()
    ) -> [Record] {
        try! read { (db) -> [Record] in
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
        return write { (db) -> Void in
            try records.save(db)
            if let completion = completion {
                db.afterNextTransactionCommit(completion)
            }
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
            try writeAndReturnError { (db) -> Void in
                numberOfChanges = try record.filter(condition).deleteAll(db)
                if let completion = completion {
                    db.afterNextTransactionCommit(completion)
                }
            }
            return numberOfChanges
        } catch {
            markDatabaseNeedsRebuildIfNeeded(error: error)
            return 0
        }
    }
    
}
