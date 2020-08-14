import Foundation
import MixinServices

struct TraceResponse: Codable {

    let asset: Asset
    let snapshot: Snapshot?
    let status: String

}

enum PaymentStatus: String, Codable {
    case pending
    case paid
}
