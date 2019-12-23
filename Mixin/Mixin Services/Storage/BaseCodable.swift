import WCDBSwift

public protocol BaseCodable: TableCodable {
    
    static var tableName: String { get }
    
}
