import Foundation

public struct TransferContactData: Codable {

    let userId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }

}
