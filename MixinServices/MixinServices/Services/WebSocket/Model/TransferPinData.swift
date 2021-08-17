import Foundation

public struct TransferPinData: Codable {
    
    public let action: String
    public let messageIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case action = "action"
        case messageIds = "message_ids"
    }
    
}

public enum TransferPinDataAction: String {
    case pin = "PIN"
    case unpin = "UNPIN"
}
