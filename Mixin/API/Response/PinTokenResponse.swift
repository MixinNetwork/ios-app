import Foundation

struct PinTokenResponse: Codable {

    let pinToken: String

    enum CodingKeys: String, CodingKey {
        case pinToken = "pin_token"
    }

}

