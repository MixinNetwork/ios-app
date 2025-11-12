import Foundation

struct Web3LimitOrderResponse {
    
    let depositDestination: String
    let displayUserID: String
    
}

extension Web3LimitOrderResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case depositDestination = "deposit_destination"
        case displayUserID = "display_user_id"
    }
    
}
