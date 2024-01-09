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

extension CompactDepositEntry: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let tagDescription: String
        if let tag {
            if tag.isEmpty {
                tagDescription = "(empty)"
            } else {
                tagDescription = tag
            }
        } else {
            tagDescription = "(null)"
        }
        return "<CompactDepositEntry dest: \(destination), tag: \(tagDescription)>"
    }
    
}
