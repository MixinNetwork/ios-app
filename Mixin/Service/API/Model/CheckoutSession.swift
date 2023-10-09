import Foundation

struct CheckoutSession {
    
    enum Status: String, Decodable {
        case pending = "pending"
        case processing = "processing"
        case challenged = "challenged"
        case challengeAbandoned = "challenge_abandoned"
        case expired = "expired"
        case approved = "approved"
        case attempted = "attempted"
        case unavailable = "unavailable"
        case declined = "declined"
        case rejected = "rejected"
    }
    
    let id: String
    let secret: String
    let instrumentID: String
    let cardPostfix: String
    let amount: Int64
    let currency: String
    let scheme: String
    let status: Status
    
}

extension CheckoutSession: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "session_id"
        case secret = "session_secret"
        case instrumentID = "instrument_id"
        case cardPostfix = "last4"
        case amount
        case currency
        case scheme
        case status
    }
    
}
