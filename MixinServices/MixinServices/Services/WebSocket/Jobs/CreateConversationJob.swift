import Foundation

public class CreateConversationJob: BaseJob {

    let conversationId: String

    public init(conversationId: String) {
        self.conversationId = conversationId
    }

    override public func getJobId() -> String {
        return "create-coversation-\(conversationId)"
    }

    override public func run() throws {
        guard !conversationId.isEmpty && conversationId != User.systemUser && conversationId != myUserId else {
            return
        }
        guard let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId), conversation.status == ConversationStatus.START.rawValue else {
            return
        }

        if conversation.category?.isEmpty ?? true {
            switch ConversationAPI.getConversation(conversationId: conversationId) {
            case let .success(response):
                ConversationDAO.shared.createConversation(conversation: response, targetStatus: ConversationStatus.SUCCESS)
                CircleConversationDAO.shared.update(conversation: response)
            case let .failure(error):
                switch error {
                case .forbidden, .notFound:
                    ConversationDAO.shared.exitGroup(conversationId: conversationId)
                default:
                    throw error
                }
            }
        } else {
            var participants = ParticipantDAO.shared.participantRequests(conversationId: conversation.conversationId, currentAccountId: currentAccountId)
            if participants.count == 0 && conversation.category == ConversationCategory.CONTACT.rawValue && conversation.ownerId != currentAccountId {
                participants = [ParticipantRequest(userId: conversation.ownerId, role: "")]
            }
            guard participants.count > 0 else {
                ConversationDAO.shared.deleteChat(conversationId: conversationId)
                return
            }

            let name = conversation.category == ConversationCategory.CONTACT.rawValue ? nil : conversation.name
            let request = ConversationRequest(conversationId: conversation.conversationId, name: name, category: conversation.category, participants: participants, duration: nil, announcement: nil)

            switch ConversationAPI.createConversation(conversation: request) {
            case let .success(response):
                ConversationDAO.shared.createConversation(conversation: response, targetStatus: ConversationStatus.SUCCESS)
            case let.failure(error):
                throw error
            }
        }
    }
}
