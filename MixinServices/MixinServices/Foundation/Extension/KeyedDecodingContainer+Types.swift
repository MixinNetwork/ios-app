import Foundation

fileprivate let urlAllowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=")

extension KeyedDecodingContainer {
    
    // For URL string with non-ASCII characters, e.g. any Chinese character, URL(string:) always returns nil,
    // which will ends up with a decoding failure. Add a percent encoding to those characters before URL init
    // https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
    
    func decode(_ type: URL.Type, forKey key: K) throws -> URL {
        let string = try decode(String.self, forKey: key)
        let percentEncoded = string.addingPercentEncoding(withAllowedCharacters: urlAllowedCharacters) ?? string
        guard let url = URL(string: percentEncoded) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid URL string for key: \(key)")
            throw DecodingError.dataCorrupted(context)
        }
        return url
    }
    
    func decodeIfPresent(_ type: URL.Type, forKey key: K) throws -> URL? {
        guard let string = try decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        let percentEncoded = string.addingPercentEncoding(withAllowedCharacters: urlAllowedCharacters) ?? string
        return URL(string: percentEncoded)
    }
    
}

extension KeyedDecodingContainer {
    
    public func decodeDecimalString(forKey key: Key) throws -> Decimal {
        let value = try decode(String.self, forKey: key)
        if let decimalValue = Decimal(string: value, locale: .enUSPOSIX) {
            return decimalValue
        } else {
            let context = DecodingError.Context(codingPath: [key], debugDescription: "Invalid decimal value: \(value)")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
}
