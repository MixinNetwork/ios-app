import Foundation

extension Encodable {
    
    var jsonRepresentation: String? {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(self) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }
    
}

extension JSONEncoder {
    
    static let `default` = JSONEncoder()
    static let snakeCase: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
}

extension JSONDecoder {
    
    static let `default` = JSONDecoder()
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
}
