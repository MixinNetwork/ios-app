import Foundation

struct OpenPerpetualOrderResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case payURL = "pay_url"
        case payAmount = "pay_amount"
        case depositDestination = "deposit_destination"
        case appID = "app_id"
    }
    
    let orderID: String
    let payURL: String?
    let payAmount: String
    let depositDestination: String?
    let appID: String
    
}
