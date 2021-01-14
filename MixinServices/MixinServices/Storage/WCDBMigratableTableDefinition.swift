import Foundation
import GRDB

protocol WCDBTableMigratable {
    var tableName: String { get }
    func createTableSQL() -> String
    func alterTableSQL(existedColumnNames: Set<String>) -> String?
}

// ⚠️ Use this struct only when migrating from WCDB
// This struct is intended to be a compatibility layer, in order to migrate tables
// created by WCDB. WCDB alters table automatically on creation if new columns are
// added to Model, instead of creating table from scratch. This struct provides
// curated function to mimic that behavior, it's not a well-defined robust struct,
// so don't use this besides migration
internal struct WCDBMigratableTableDefinition<Record: TableRecord & DatabaseColumnConvertible> {
    
    let tableName: String
    let columns: [ColumnDefinition]
    let constraints: String?
    
    init(constraints: String?, columns: [ColumnDefinition]) {
        self.tableName = Record.databaseTableName
        self.columns = columns
        self.constraints = constraints
    }
    
}

extension WCDBMigratableTableDefinition: WCDBTableMigratable {
    
    func createTableSQL() -> String {
        let columnDefinitions = columns.map(\.sqlDefinition).joined(separator: ", ")
        var sql = "CREATE TABLE \(Record.databaseTableName)(\(columnDefinitions)"
        if let constraints = constraints {
            sql += ", \(constraints)"
        }
        sql += ")"
        return sql
    }
    
    func alterTableSQL(existedColumnNames: Set<String>) -> String? {
        let columnsToAdd = columns.filter { (column) -> Bool in
            !existedColumnNames.contains(column.name)
        }
        if columnsToAdd.isEmpty {
            return nil
        } else {
            var sqls: [String] = []
            for column in columnsToAdd {
                sqls.append("ALTER TABLE \(Record.databaseTableName) ADD COLUMN \(column.name) \(column.constraints);")
            }
            if sqls.isEmpty {
                return nil
            } else {
                return sqls.joined(separator: "\n")
            }
        }
    }
    
}

extension WCDBMigratableTableDefinition {
    
    struct ColumnDefinition {
        
        let name: String
        let constraints: String
        
        var sqlDefinition: String {
            name + " " + constraints
        }
        
        init(key: Record.CodingKeys, constraints: String) {
            self.name = key.stringValue
            self.constraints = constraints
        }
        
    }
    
}
