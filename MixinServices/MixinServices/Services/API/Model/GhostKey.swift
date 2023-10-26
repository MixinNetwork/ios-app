import Foundation

public struct GhostKey: Decodable {
    
    public let type: String
    public let mask: String
    public let keys: [String]
    
}
