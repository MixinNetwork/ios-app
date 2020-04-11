import Foundation

struct ConversationCircleRequest {

    let action: CircleConversationAction
    let circleId: String

    var jsonObject: [String: String] {
        return ["circle_id": circleId, "action": action.rawValue]
    }

}
