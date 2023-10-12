import Foundation

struct CheckoutPayment {
    
    enum Status: String, Decodable {
        case authorized = "Authorized"
        case captured = "Captured"
        case declined = "Declined"
    }
    
    let id: String
    let status: Status
    
}

extension CheckoutPayment: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "payment_id"
        case status
    }
    
}
