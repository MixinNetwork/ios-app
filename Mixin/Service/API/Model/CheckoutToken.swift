import Foundation

struct CheckoutToken {
    
    let token: String
    let tokenFormat: String
    let scheme: String
    
}

extension CheckoutToken: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case token
        case tokenFormat = "token_format"
        case scheme
    }
    
}
