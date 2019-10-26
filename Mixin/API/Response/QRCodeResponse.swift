import Foundation

struct QRCodeResponse: Encodable {

    let type: String
    var user: UserResponse? = nil
    var conversation: ConversationResponse? = nil
    var authorization: AuthorizationResponse? = nil
    var multisig: MultisigResponse? = nil
}

extension QRCodeResponse: Decodable {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.getString(key: .type)
        switch type {
        case "user":
            user = try UserResponse(from: decoder)
        case "conversation":
            conversation = try ConversationResponse(from: decoder)
        case "authorization":
            authorization = try AuthorizationResponse(from: decoder)
        case "multisig_request":
            multisig = try MultisigResponse(from: decoder)
        default:
            break
        }

    }

}
