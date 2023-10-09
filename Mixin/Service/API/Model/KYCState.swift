import Foundation

enum KYCState: String, Decodable {
    case initial
    case pending
    case success
    case retry
    case blocked
    case ignore
}
