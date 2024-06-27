import Foundation

public struct SafeScheme {
    
    public let target: URL
    
}

extension SafeScheme: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case target
    }
    
    public init(from decoder: any Decoder) throws {
        // If `target` is decoded as a URL, it will incorrectly handle the
        // percent-encoded parts of the string, causing double escaping.
        // The exact reason is unclear, but it might be a bug in Swift.
        // Decoding it as a String does not have this issue.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let urlString = try container.decode(String.self, forKey: .target)
        if let url = URL(string: urlString) {
            self.target = url
        } else {
            throw DecodingError.dataCorruptedError(forKey: .target, in: container, debugDescription: "Invalid URL String")
        }
    }
    
}

