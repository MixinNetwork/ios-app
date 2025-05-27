import Foundation

extension KeyedDecodingContainer {
    
    public func decode(
        _ type: Decimal.Type,
        forKey key: KeyedDecodingContainer<K>.Key
    ) throws -> Decimal {
        let string = try decode(String.self, forKey: key)
        if let decimal = Decimal(string: string, locale: .enUSPOSIX) {
            return decimal
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Invalid Decimal"
            )
        }
    }
    
}
