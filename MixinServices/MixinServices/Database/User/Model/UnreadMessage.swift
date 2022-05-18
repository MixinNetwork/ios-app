import Foundation
import GRDB

public struct UnreadMessage {
    let id: String
    let expireIn: Int64?
    let expireAt: Int64?
}

extension UnreadMessage: Decodable, MixinFetchableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case id
        case expireIn = "expire_in"
        case expireAt = "expire_at"
    }
    
}
