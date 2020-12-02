import GRDB

public protocol DatabaseColumnConvertible {
    associatedtype CodingKeys: CodingKey
}

extension DatabaseColumnConvertible {
    
    public static func column(of key: Self.CodingKeys) -> Column {
        Column(key)
    }
    
}
