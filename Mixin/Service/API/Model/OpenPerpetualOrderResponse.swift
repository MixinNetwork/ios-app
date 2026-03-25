import Foundation

struct OpenPerpetualOrderResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case appID = "app_id"
        case orderID = "order_id"
        case payAmount = "pay_amount"
        case paymentURL = "payment_url"
    }
    
    let appID: String
    let orderID: String
    let payAmount: String
    let paymentURL: String
    
}
