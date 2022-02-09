import Foundation

public struct PaymentResponse: Codable {

    public let status: String

}

public enum PaymentStatus: String, Codable {
    case pending
    case paid
}
