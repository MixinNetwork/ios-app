import Foundation

public struct PaymentResponse: Codable {
    
    public let recipient: UserResponse
    public let asset: Asset
    public let amount: String
    public let status: String
    
}

public enum PaymentStatus: String, Codable {
    case pending
    case paid
}
