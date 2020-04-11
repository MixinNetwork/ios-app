import WCDBSwift

public protocol BaseDecodable: TableDecodable {
    
    static var tableName: String { get }
    
}

public protocol BaseEncodable: TableEncodable {
    
    static var tableName: String { get }
    
}

public typealias BaseCodable = BaseEncodable & BaseDecodable
