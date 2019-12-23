import Foundation

public struct QRCodeResponse: Encodable {

    let type: String
    var user: UserResponse? = nil
    var conversation: ConversationResponse? = nil
    var authorization: AuthorizationResponse? = nil
    var multisig: MultisigResponse? = nil
    var payment: PaymentCodeResponse? = nil
    
}

extension QRCodeResponse: Decodable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        switch type {
        case "user":
            user = try UserResponse(from: decoder)
        case "conversation":
            conversation = try ConversationResponse(from: decoder)
        case "authorization":
            authorization = try AuthorizationResponse(from: decoder)
        case "multisig_request":
            multisig = try MultisigResponse(from: decoder)
        case "payment":
            payment = try PaymentCodeResponse(from: decoder)
        default:
            break
        }

    }

}
