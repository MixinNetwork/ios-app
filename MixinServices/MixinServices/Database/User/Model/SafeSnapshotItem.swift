import Foundation

public final class SafeSnapshotItem: SafeSnapshot, InscriptionContentProvider {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case opponentUserID = "opponent_user_id"
        case opponentFullname = "opponent_fullname"
        case opponentAvatarURL = "opponent_avatar_url"
        case inscriptionContentType = "inscription_content_type"
        case inscriptionContentURL = "inscription_content_url"
        case inscriptionCollectionIconURL = "inscription_collection_icon"
    }
    
    public let tokenSymbol: String?
    
    public let opponentUserID: String?
    public let opponentFullname: String?
    public let opponentAvatarURL: String?
    
    public let inscriptionContentType: String?
    public let inscriptionContentURL: String?
    public var inscriptionCollectionIconURL: String?
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        
        self.tokenSymbol = try container.decodeIfPresent(String.self, forKey: .tokenSymbol)
        
        self.opponentUserID = try container.decodeIfPresent(String.self, forKey: .opponentUserID)
        self.opponentFullname = try container.decodeIfPresent(String.self, forKey: .opponentFullname)
        self.opponentAvatarURL = try container.decodeIfPresent(String.self, forKey: .opponentAvatarURL)
        
        self.inscriptionContentType = try container.decodeIfPresent(String.self, forKey: .inscriptionContentType)
        self.inscriptionContentURL = try container.decodeIfPresent(String.self, forKey: .inscriptionContentURL)
        self.inscriptionCollectionIconURL = try container.decodeIfPresent(String.self, forKey: .inscriptionCollectionIconURL)
        
        try super.init(from: decoder)
    }
    
}
