import Foundation
import GRDB

protocol ColumnMigratable {
    var tableName: String { get }
    func createTableSQL() -> String
    func alterTableSQL(existedColumnNames: Set<String>) -> String?
}

// ⚠️ Use this struct only when migrating from database which mayin absence of column
// This struct is intended to be a compatibility layer, in order to migrate tables
// created by elder version. Before then, it alters table automatically on creation if
// new columns are added to Model, instead of creating table from scratch. This struct
// provides curated function to mimic that behavior, it's not a well-defined robust
// struct, so don't use this besides migration
internal struct ColumnMigratableTableDefinition<Record: TableRecord & DatabaseColumnConvertible> {
    
    let columns: [ColumnDefinition]
    let constraints: String?
    
    init(constraints: String?, columns: [ColumnDefinition]) {
        self.columns = columns
        self.constraints = constraints
    }
    
}

extension ColumnMigratableTableDefinition: ColumnMigratable {
    
    var tableName: String {
        Record.databaseTableName
    }
    
    func createTableSQL() -> String {
        let columnDefinitions = columns.map(\.sqlDefinition).joined(separator: ", ")
        var sql = "CREATE TABLE \(tableName)(\(columnDefinitions)"
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
                sqls.append("ALTER TABLE \(tableName) ADD COLUMN \(column.sqlDefinition);")
            }
            if sqls.isEmpty {
                return nil
            } else {
                return sqls.joined(separator: "\n")
            }
        }
    }
    
}

extension ColumnMigratableTableDefinition {
    
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
