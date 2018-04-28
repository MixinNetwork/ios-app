import Foundation

struct PaymentResponse: Codable {

    let recipient: UserResponse
    let asset: Asset
    let amount: String
    let status: String

}

enum PaymentStatus: String, Codable {
    case pending
    case paid
}
