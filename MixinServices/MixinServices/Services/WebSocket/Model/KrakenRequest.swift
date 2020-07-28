import Foundation

public struct KrakenRequest {
    
    public enum Action {
        case invite(recipients: [String])
        case publish(sdp: String)
        case subscribe
        case answer(sdp: String)
        case trickle(candidate: String)
        case end
        case cancel
        case decline(recipientId: String)
        case restart(sdp: String)
    }
    
    public let callUUID: UUID
    public let conversationId: String
    public let trackId: String?
    public let action: Action
    
    var blazeMessage: BlazeMessage {
        var param = BlazeMessageParam()
        param.messageId = UUID().uuidString.lowercased()
        param.conversationId = conversationId
        param.trackId = trackId
        switch action {
        case .invite(let ids):
            param.category = MessageCategory.KRAKEN_INVITE.rawValue
            param.recipientIds = ids
        case .publish(let sdp):
            param.category = MessageCategory.KRAKEN_PUBLISH.rawValue
            param.jsep = sdp.base64Encoded()
        case .subscribe:
            param.category = MessageCategory.KRAKEN_SUBSCRIBE.rawValue
        case .answer(let sdp):
            param.category = MessageCategory.KRAKEN_ANSWER.rawValue
            param.jsep = sdp.base64Encoded()
        case .trickle(let candidate):
            param.category = MessageCategory.KRAKEN_TRICKLE.rawValue
            param.candidate = candidate
        case .cancel:
            param.category = MessageCategory.KRAKEN_CANCEL.rawValue
        case .decline(let id):
            param.category = MessageCategory.KRAKEN_DECLINE.rawValue
            param.recipientId = id
        case .end:
            param.category = MessageCategory.KRAKEN_END.rawValue
        case .restart(let sdp):
            param.category = MessageCategory.KRAKEN_RESTART.rawValue
            param.jsep = sdp.base64Encoded()
            assert(trackId != nil)
        }
        return BlazeMessage(params: param, action: BlazeMessageAction.createKraken.rawValue)
    }
    
    public init(callUUID: UUID, conversationId: String, trackId: String?, action: Action) {
        self.callUUID = callUUID
        self.conversationId = conversationId
        self.trackId = trackId
        self.action = action
    }
    
}

extension KrakenRequest: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "<KrakenRequest callUUID: \(callUUID.uuidString), conversationId: \(conversationId), trackId: \(trackId), action: \(action)>"
    }
    
}
