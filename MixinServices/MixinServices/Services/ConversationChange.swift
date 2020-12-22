import Foundation

public struct ConversationChange {
    
    public let conversationId: String
    public let action: Action
    
    public enum Action {
        case reload
        case update(conversation: ConversationItem)
        case updateConversation(conversation: ConversationResponse)
        case updateConversationStatus(status: ConversationStatus)
        case updateGroupIcon(iconUrl: String)
        case updateMessage(messageId: String)
        case updateMessageStatus(messageId: String, newStatus: MessageStatus)
        case updateMessageMentionStatus(messageId: String, newStatus: MessageMentionStatus)
        case updateMediaStatus(messageId: String, mediaStatus: MediaStatus)
        case updateUploadProgress(messageId: String, progress: Double)
        case updateDownloadProgress(messageId: String, progress: Double)
        case updateMediaContent(messageId: String, message: Message)
        case startedUpdateConversation
        case recallMessage(messageId: String)
    }
    
    public init(conversationId: String, action: ConversationChange.Action) {
        self.conversationId = conversationId
        self.action = action
    }
    
}
