import Foundation

struct TIPSignResponse: Decodable {
    
    struct SignData: Codable {
        let cipher: String
    }
    
    let data: SignData
    let signature: String
    
}
