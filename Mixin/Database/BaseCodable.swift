import WCDBSwift

protocol BaseCodable: TableCodable {

    static var tableName: String { get }

}
