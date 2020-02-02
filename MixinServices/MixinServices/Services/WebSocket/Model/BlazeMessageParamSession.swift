
struct BlazeMessageParamSession: Codable {

    let userId: String
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionId = "session_id"
    }

}
