import Foundation

public struct CompactDepositEntry {
    
    public let destination: String
    public let tag: String?
    
}

extension CompactDepositEntry: Decodable, DatabaseColumnConvertible, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case destination
        case tag
    }
    
}
