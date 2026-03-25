import Foundation

struct ClosePerpetualOrderResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
    }
    
    let orderID: String
    
}
