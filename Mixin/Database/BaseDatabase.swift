import WCDBSwift
import Bugsnag

class BaseDatabase {

    internal var database: Database!
    private static var isTraced = false

    internal init() {
        trace()
        configure()
    }

    func configure(reset: Bool = false) {

    }

    func close() {
        database?.close()
    }

    func trace() {
        guard !BaseDatabase.isTraced else {
            return
        }
        BaseDatabase.isTraced = true
        #if DEBUG
            Database.globalTrace(ofPerformance: { (tag, sqls, cost) in
                let millisecond = UInt64(cost) / NSEC_PER_MSEC
                if millisecond > 100 {
                    sqls.forEach({ (arg) in
                        print("[WCDB][Performance]SQL: \(arg.key) Count: \(arg.value)")
                    })
                    print("[WCDB][Performance]Total cost \(millisecond) ms")
                }
            })
        #endif

        Database.globalTrace(ofError: {(error) in
            switch error.type {
            case .warning, .sqliteGlobal:
                break
            default:
                Bugsnag.notifyError(error)
            }
            #if DEBUG
            print("[WCDB][ERROR]\(error.description)")
            #endif
        })
    }

    func getStringValues(column: ColumnResultConvertible, tableName: String, isDistinct: Bool = false, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, inTransaction: Bool = true) -> [String] {
        if inTransaction {
            var result = [String]()
            try! database.runTransaction {
                result = self.getStringValues(column: column, tableName: tableName, isDistinct: isDistinct, condition: condition, orderBy: orderList, limit: limit, inTransaction: false)
            }
            return result
        } else {
            let values: FundamentalColumn
            if isDistinct {
                values = try! database.tryGetDistinctColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
            } else {
                values = try! database.tryGetColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
            }
            var result = [String]()
            for value in values {
                result.append(value.stringValue)
            }
            return result
        }
    }

    func getInt32Values(column: ColumnResultConvertible, tableName: String, isDistinct: Bool = false, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, inTransaction: Bool = true) -> [Int32] {
        if inTransaction {
            var result = [Int32]()
            try! database.runTransaction {
                result = self.getInt32Values(column: column, tableName: tableName, isDistinct: isDistinct, condition: condition, orderBy: orderList, limit: limit, inTransaction: false)
            }
            return result
        } else {
            let values: FundamentalColumn
            if isDistinct {
                values = try! database.tryGetDistinctColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
            } else {
                values = try! database.tryGetColumn(on: column, fromTable: tableName, where: condition, orderBy: orderList, limit: limit)
            }
            var result = [Int32]()
            for value in values {
                result.append(value.int32Value)
            }
            return result
        }
    }

    func getDictionary(key: ColumnResult, value: ColumnResult, tableName: String, condition: Condition? = nil) -> [String: String] {
        let rows = try! database.tryGetRows(on: [key, value], fromTable: tableName, where: condition)
        var result = [String: String]()
        for row in rows {
            result[row[0].stringValue] = row[1].stringValue
        }
        return result
    }

    func isTableEmpty<T: BaseCodable>(type: T.Type) throws -> Bool {
        return try database.getValue(on: T.Properties.all[0], fromTable: T.tableName, limit: 1).type == .null
    }

    func isExist<T: BaseCodable>(type: T.Type, condition: Condition, inTransaction: Bool = true) -> Bool {
        if inTransaction {
            var result = false
            try! database.runTransaction {
                result = try! database.getValue(on: type.Properties.all[0].asColumn(), fromTable: type.tableName, where: condition).type != .null
            }
            return result
        } else {
            return try! database.tryGetValue(on: type.Properties.all[0].asColumn(), fromTable: type.tableName, where: condition).type != .null
        }
    }

    func getCodables<T: TableCodable>(on propertyConvertibleList: [PropertyConvertible] = T.Properties.all, sql: String, values: [ColumnEncodable] = [], inTransaction: Bool = true) -> [T] {
        if inTransaction {
            var result = [T]()
            try! database.runTransaction {
                result = try database.prepareSelectSQL(on: propertyConvertibleList, sql: sql, values: values).allObjects()
            }
            return result
        } else {
            return try! database.execQuery(on: propertyConvertibleList, sql: sql, values: values).allObjects()
        }
    }

    func getCodables<T: BaseCodable>(condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, inTransaction: Bool = true) -> [T] {
        if inTransaction {
            var result = [T]()
            try! database.runTransaction {
                result = try database.getObjects(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList, limit: limit)
            }
            return result
        } else {
            return try! database.tryGetObjects(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList, limit: limit)
        }
    }

    func getCodables<T: Codable>(on propertyConvertibleList: [PropertyConvertible] = [], fromTable: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, inTransaction: Bool = true, callback: (FundamentalRowXColumn) -> [T]) -> [T] {
        if inTransaction {
            var result = [T]()
            try! database.runTransaction {
                result = callback(try database.getRows(on: propertyConvertibleList, fromTable: fromTable, where: condition, orderBy: orderList, limit: limit))
            }
            return result
        } else {
            return callback(try! database.tryGetRows(on: propertyConvertibleList, fromTable: fromTable, where: condition, orderBy: orderList, limit: limit))
        }
    }

    func getCodables<T>(callback: (Database) throws -> [T]) -> [T] {
        do {
            return try callback(database)
        } catch {
            Bugsnag.notifyError(error)
        }
        return []
    }

    func getCodable<T: BaseCodable>(condition: Condition, orderBy orderList: [OrderBy]? = nil, inTransaction: Bool = true) -> T? {
        if inTransaction {
            var result: T?
            try! database.runTransaction {
                result = try database.getObject(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList)
            }
            return result
        } else {
            return try! database.tryGetObject(on: T.Properties.all, fromTable: T.tableName, where: condition, orderBy: orderList)
        }
    }

    func scalar(on: ColumnResultConvertible, fromTable: String, condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, inTransaction: Bool = true) -> FundamentalValue? {
        var result: FundamentalValue?
        if inTransaction {
            try! database.runTransaction {
                result = try database.getValue(on: on, fromTable: fromTable, where: condition, orderBy: orderList, limit: 1)
            }
        } else {
            result = try! database.tryGetValue(on: on, fromTable: fromTable, where: condition, orderBy: orderList, limit: 1)
        }
        guard let value = result else {
            return nil
        }
        return value.type == .null ? nil : value
    }

    func getCount(on: ColumnResultConvertible, fromTable: String, condition: Condition? = nil, inTransaction: Bool = true) -> Int {
        if inTransaction {
            var result = 0
            try! database.runTransaction {
                result = Int(try database.getValue(on: on, fromTable: fromTable, where: condition).int32Value)
            }
            return result
        } else {
            return Int(try! database.tryGetValue(on: on, fromTable: fromTable, where: condition).int32Value)
        }
    }

    @discardableResult
    func transaction(callback: (Database) throws -> Void) -> Bool {
        try! database.runTransaction {
            try callback(database)
        }
        return true
    }

    @discardableResult
    func update(maps: [(PropertyConvertible, ColumnEncodable?)], tableName: String, condition: Condition? = nil) -> Bool {
        var keys = [PropertyConvertible]()
        var values = [ColumnEncodable]()
        for (key, value) in maps {
            guard let val = value else {
                continue
            }
            keys.append(key)
            values.append(val)
        }
        try! database.runTransaction {
            try database.update(table: tableName, on: keys, with: values, where: condition)
        }
        return true
    }

    @discardableResult
    func insert<T: BaseCodable>(objects: [T], on propertyConvertibleList: [PropertyConvertible]? = nil) -> Bool {
        try! database.runTransaction {
            try database.insert(objects: objects, on: propertyConvertibleList, intoTable: T.tableName)
        }
        return true
    }

    @discardableResult
    func insertOrReplace<T: BaseCodable>(objects: [T], on propertyConvertibleList: [PropertyConvertible]? = nil) -> Bool {
        try! database.runTransaction {
            try database.insertOrReplace(objects: objects, on: propertyConvertibleList, intoTable: T.tableName)
        }
        return true
    }

    func deleteAll(table: String) {
        try! database.runTransaction {
            guard try database.isTableExists(table) else {
                return
            }
            try database.delete(fromTable: table)
        }
    }

    @discardableResult
    func delete(table: String, condition: Condition, cascadeDelete: Bool = false) -> Int {
        var result = 0
        try! database.runTransaction {
            if cascadeDelete {
                try database.exec(StatementPragma().pragma(Pragma.foreignKeys, to: true))
            }
            let delete = try database.prepareDelete(fromTable: table).where(condition)
            try delete.execute()
            result = delete.changes ?? 0
        }
        return result
    }
}

internal extension Database {

    internal func create<T: BaseCodable>(of rootType: T.Type) throws{
        try create(table: T.tableName, of: rootType)
    }

}

extension Database {

    func isColumnExist(tableName: String, columnName: String) throws -> Bool {
        return try getValue(on: Master.Properties.sql, fromTable: Master.builtinTableName, where: Master.Properties.tableName == tableName && Master.Properties.type == "table").stringValue.contains(columnName)
    }

}

fileprivate extension Database {

    func runTransaction(_ transaction: () throws -> Void) throws {
        do {
            try run(transaction: transaction)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetValue(on result: ColumnResultConvertible, fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, offset: Offset? = nil) throws -> FundamentalValue {
        do {
            return try getValue(on: result, fromTable: table, where: condition, orderBy: orderList, limit: limit, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetObjects<Object: TableDecodable>(on propertyConvertibleList: [PropertyConvertible], fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, offset: Offset? = nil) throws -> [Object] {
        do {
            return try getObjects(on: propertyConvertibleList, fromTable: table, where: condition, orderBy: orderList, limit: limit, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetObject<Object: TableDecodable>(on propertyConvertibleList: [PropertyConvertible], fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, offset: Offset? = nil) throws -> Object? {
        do {
            return try getObject(on: propertyConvertibleList, fromTable: table, where: condition, orderBy: orderList, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetRows(on columnResultConvertibleList: [ColumnResultConvertible], fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, offset: Offset? = nil) throws -> FundamentalRowXColumn {
        do {
            return try getRows(on: columnResultConvertibleList, fromTable: table, where: condition, orderBy: orderList, limit: limit, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetColumn(on result: ColumnResultConvertible, fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, offset: Offset? = nil) throws -> FundamentalColumn {
        do {
            return try getColumn(on: result, fromTable: table, where: condition, orderBy: orderList, limit: limit, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func tryGetDistinctColumn(on result: ColumnResultConvertible, fromTable table: String, where condition: Condition? = nil, orderBy orderList: [OrderBy]? = nil, limit: Limit? = nil, offset: Offset? = nil) throws -> FundamentalColumn {
        do {
            return try getDistinctColumn(on: result, fromTable: table, where: condition, orderBy: orderList, limit: limit, offset: offset)
        } catch {
            notifyError(error)
            throw error
        }
    }

    func execQuery(on propertyConvertibleList: [PropertyConvertible], sql: String, values: [ColumnEncodable] = []) throws -> SelectSQL {
        do {
            return try prepareSelectSQL(on: propertyConvertibleList, sql: sql, values: values)
        } catch {
            notifyError(error)
            throw error
        }
    }

    private func notifyError(_ error: Swift.Error) {
        if let err = error as? WCDBSwift.Error {
            var userInfo = UIApplication.getTrackUserInfo()
            userInfo["sql"] = err.sql ?? ""
            userInfo["description"] = err.description
            userInfo["callStack"] = Thread.callStackSymbols.first ?? ""
            UIApplication.trackError("BaseDatabase", action: "track sql error", userInfo: userInfo)
        } else {
            Bugsnag.notifyError(error)
        }
    }
}
