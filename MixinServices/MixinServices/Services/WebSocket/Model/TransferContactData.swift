import Foundation

public class TransferContactData: Codable {
    
    public let userId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
    
    public init(userId: String) {
        self.userId = userId
    }
    
}
