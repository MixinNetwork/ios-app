import Foundation

struct PinTokenResponse: Codable {

    public let pinToken: String

    enum CodingKeys: String, CodingKey {
        case pinToken = "pin_token"
    }

}

