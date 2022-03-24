import Foundation

public struct ConversationCircleRequest {
    
    public let action: CircleConversationAction
    public let circleId: String
    
    var jsonObject: [String: String] {
        return ["circle_id": circleId, "action": action.rawValue]
    }
    
    public init(action: CircleConversationAction, circleId: String) {
        self.action = action
        self.circleId = circleId
    }
    
}
