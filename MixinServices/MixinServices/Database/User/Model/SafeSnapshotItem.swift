import Foundation

public final class SafeSnapshotItem: SafeSnapshot {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case opponentUserID = "opponent_user_id"
        case opponentFullname = "opponent_fullname"
        case opponentAvatarURL = "opponent_avatar_url"
    }
    
    public let tokenSymbol: String?
    
    public let opponentUserID: String?
    public let opponentFullname: String?
    public let opponentAvatarURL: String?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        
        self.tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        
        self.opponentUserID = try container.decodeIfPresent(String.self, forKey: .opponentUserID)
        self.opponentFullname = try container.decodeIfPresent(String.self, forKey: .opponentFullname)
        self.opponentAvatarURL = try container.decodeIfPresent(String.self, forKey: .opponentAvatarURL)
        
        try super.init(from: decoder)
    }
    
}
