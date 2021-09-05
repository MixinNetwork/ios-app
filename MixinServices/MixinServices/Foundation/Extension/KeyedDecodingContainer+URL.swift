import Foundation

// For URL string with non-ASCII characters, URL(string:) always returns nil,
// which will ends up with a decoding failure. Add a percent encoding before URL init
extension KeyedDecodingContainer {
    
    func decode(_ type: URL.Type, forKey key: K) throws -> URL {
        let string = try decode(String.self, forKey: key)
        let percentEncoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
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
        let percentEncoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
        return URL(string: percentEncoded)
    }
    
}
