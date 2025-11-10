import Foundation

public struct ReferralCodeInfo {
    
    public let code: String
    public let inviteePercent: String
    public let inviterUserID: String
    
}

extension ReferralCodeInfo: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case code
        case inviteePercent = "invitee_percent"
        case inviterUserID = "inviter_user_id"
    }
    
}
