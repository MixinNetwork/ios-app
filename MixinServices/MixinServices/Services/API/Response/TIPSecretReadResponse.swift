import Foundation

struct TIPSecretReadResponse {
    
    let seed: Data
    
}

extension TIPSecretReadResponse: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case seed = "seed_base64"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let encoded = try container.decode(String.self, forKey: .seed)
        guard !encoded.isEmpty else {
            let context = DecodingError.Context(codingPath: [CodingKeys.seed], debugDescription: "Empty seed")
            throw DecodingError.dataCorrupted(context)
        }
        if let decoded = Data(base64URLEncoded: encoded) {
            self.seed = decoded
        } else {
            let context = DecodingError.Context(codingPath: [CodingKeys.seed], debugDescription: "Base64url decoding failed")
            throw DecodingError.dataCorrupted(context)
        }
    }
    
}
