import Foundation
import MixinServices

struct PaymentResponse: Codable {

    let status: String

}

enum PaymentStatus: String, Codable {
    case pending
    case paid
}
