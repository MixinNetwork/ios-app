import WCDBSwift

public class BaseDatabase {
    
    internal var database: Database!
    
    private static var isTraced = false
    
    internal init() {
        trace()
    }
    
    public func close() {
        database?.close()
    }
    
    public func removeDatabase(databaseURL: URL) {
        let semaphore = DispatchSemaphore(value: 0)
        database.close {
            try? FileManager.default.removeItem(at: databaseURL)
            semaphore.signal()
        }
        semaphore.wait()
    }
    
    public func getDatabaseVersion() -> Int {
        return try! database.getDatabaseVersion()
    }
    
    public func trace() {
        guard !BaseDatabase.isTraced else {
            return
        }
        BaseDatabase.isTraced = true
        #if DEBUG
        Database.globalTrace(ofPerformance: { (tag, sqls, cost) in
            let millisecond = UInt64(cost) / NSEC_PER_MSEC
            if millisecond > 200 {
                sqls.forEach({ (arg) in
                    print("[WCDB][Performance]SQL: \(arg.key)")
                })
                print("[WCDB][Performance]Total cost \(millisecond) ms")
            }
        })
        #endif
        
        Database.globalTrace(ofError: {(error) in
            switch error.type {
            case .warning, .sqliteGlobal:
                return
            default:
                if error.type == .sqlite && error.code.value == 9 {
                    // interrupted
                    return
                } else if error.type == .sqlite && error.operationValue == 3 {
                    if LoginManager.shared.isLoggedIn && (error.path?.hasSuffix("mixin.db") ?? false) {
                        // no such table
                        AppGroupUserDefaults.User.needsRebuildDatabase = true
                    }
                }
                Reporter.report(error: error)
            }
        })
    }
    
    public func getStringValues(column: ColumnResultConvertible, tableName: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil) -> [String] {
        let values = try! database.getColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
        return values.map { $0.stringValue }
    }
    
    public func getStringValues(sql: String, values: [ColumnEncodable] = []) -> [String] {
        return try! database.prepareSelectSQL(sql: sql, values: values).getStringValues()
    }
    
    public func getInt32Values(column: ColumnResultConvertible, tableName: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil) -> [Int32] {
        let values = try! database.getColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
        return values.map { $0.int32Value }
    }
    
    public func getRowId(tableName: String, condition: Condition) -> Int64 {
        let sql = "SELECT ROWID FROM \(tableName) WHERE \(condition.asExpression())"
        return try! database.prepareSelectSQL(sql: sql, values: []).getValue().int64Value
    }
    
    public func getDictionary(key: ColumnResult, value: ColumnResult, tableName: String, condition: Condition? = nil) -> [String: String] {
        let rows = try! database.getRows(on: [key, value], fromTable: tableName, where: condition)
        var result = [String: String]()
        for row in rows {
            result[row[0].stringValue] = row[1].stringValue
        }
        return result
    }
    
    public func isTableEmpty<T: BaseCodable>(type: T.Type) throws -> Bool {
        return try database.getValue(on: T.Properties.all[0], fromTable: T.tableName, limit: 1).type == .null
    }
    
    public func isExist<T: BaseCodable>(type: T.Type, condition: Condition) -> Bool {
        return try! database.getValue(on: type.Properties.all[0].asColumn(), fromTable: type.tableName, where: condition).type != .null
    }
    
    public func getCodables<T: TableCodable>(on propertyConvertibleList: [PropertyConvertible] = T.Properties.all, sql: String, values: [ColumnEncodable] = []) -> [T] {
        return try! database.prepareSelectSQL(on: propertyConvertibleList, sql: sql, values: values).allObjects()
    }
    
    public func getCodables<T: BaseCodable>(condition: Condition? = nil, offset: Offset? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil) -> [T] {
        return try! database.getObjects(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList, limit: limit, offset: offset)
    }
    
    public func getCodables<T: Codable>(on propertyConvertibleList: [PropertyConvertible] = [], fromTable: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, callback: (FundamentalRowXColumn) -> [T]) -> [T] {
        return callback(try! database.getRows(on: propertyConvertibleList, fromTable: fromTable, where: condition, orderBy: orderList, limit: limit))
    }
    
    public func getCodables<T>(callback: (Database) throws -> [T]) -> [T] {
        do {
            return try callback(database)
        } catch {
            Reporter.report(error: error)
        }
        return []
    }
    
    public func getCodables<T: TableDecodable>(statement: StatementSelect) -> [T] {
        return try! database.getObjects(on: T.Properties.all, stmt: statement)
    }
    
    public func getCodable<T: BaseCodable>(condition: Condition, orderBy orderList: [OrderBy]? = nil) -> T? {
        return try! database.getObject(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList)
    }
    
    public func scalar(on: ColumnResultConvertible, fromTable: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil) -> FundamentalValue? {
        let value = try! database.getValue(on: on, fromTable: fromTable, where: condition, orderBy: orderList, limit: 1)
        return value.type == .null ? nil : value
    }
    
    public func scalar(sql: String, values: [ColumnEncodable] = []) -> FundamentalValue {
        return try! database.prepareSelectSQL(sql: sql, values: values).getValue()
    }
    
    public func getCount(on: ColumnResultConvertible, fromTable: String, condition: Condition? = nil) -> Int {
        return Int(try! database.getValue(on: on, fromTable: fromTable, where: condition).int32Value)
    }
    
    @discardableResult
    public func transaction(callback: (Database) throws -> Void) -> Bool {
        try! database.run(transaction: {
            try callback(database)
        })
        return true
    }
    
    @discardableResult
    public func update(maps: [(PropertyConvertible, ColumnEncodable?)], tableName: String, condition: Condition? = nil) -> Bool {
        try! database.update(maps: maps, tableName: tableName, condition: condition)
        return true
    }
    
    @discardableResult
    public func insert<T: BaseCodable>(objects: [T], on propertyConvertibleList: [PropertyConvertible]? = nil) -> Bool {
        guard objects.count > 0 else {
            return true
        }
        try! database.insert(objects: objects, on: propertyConvertibleList, intoTable: T.tableName)
        return true
    }
    
    @discardableResult
    public func insertOrReplace<T: BaseCodable>(objects: [T], on propertyConvertibleList: [PropertyConvertible]? = nil) -> Bool {
        guard objects.count > 0 else {
            return true
        }
        try! database.insertOrReplace(objects: objects, on: propertyConvertibleList, intoTable: T.tableName)
        return true
    }
    
    @discardableResult
    public func delete(table: String, condition: Condition) -> Int {
        let delete = try! database.prepareDelete(fromTable: table).where(condition)
        try! delete.execute()
        return delete.changes ?? 0
    }
    
    public func execute(sql: String, values: [ColumnEncodable]) {
        let stmt = try! database.prepareUpdateSQL(sql: sql)
        try! stmt.execute(with: values)
    }
    
}

extension Database {
    
    public func create<T: BaseCodable>(of rootType: T.Type) throws {
        try create(table: T.tableName, of: rootType)
    }
    
    public func update(maps: [(PropertyConvertible, ColumnEncodable?)], tableName: String, condition: Condition? = nil) throws {
        var keys = [PropertyConvertible]()
        var values = [ColumnEncodable?]()
        for (key, value) in maps {
            keys.append(key)
            values.append(value)
        }
        try update(table: tableName, on: keys, with: values, where: condition)
    }
    
}

extension Database {
    
    public func isColumnExist(tableName: String, columnName: String) throws -> Bool {
        return try getValue(on: Master.Properties.sql, fromTable: Master.builtinTableName, where: Master.Properties.tableName == tableName && Master.Properties.type == "table").stringValue.contains(columnName)
    }
    
}

extension Database {
    
    public func setDatabaseVersion(version: Int) throws {
        try prepareUpdateSQL(sql: "PRAGMA user_version = \(version)").execute()
    }
    
    public func getDatabaseVersion() throws -> Int  {
        return Int(try prepareSelectSQL(sql: "PRAGMA user_version").getValue().int32Value)
    }
    
}
