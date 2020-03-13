import Foundation

public class ExitConversationJob: BaseJob {

    let conversationId: String

    public init(conversationId: String) {
        self.conversationId = conversationId
    }

    override public func getJobId() -> String {
        return "exit-coversation-\(conversationId)"
    }

    override public func run() throws {
        let conversationId = self.conversationId
        guard !isCancelled, !conversationId.isEmpty, ConversationDAO.shared.getConversationStatus(conversationId: conversationId) == ConversationStatus.QUIT.rawValue else {
            return
        }

        switch ConversationAPI.shared.exitConversation(conversationId: conversationId) {
        case .success:
            ConversationDAO.shared.clearConversation(conversationId: conversationId, exitConversation: true, autoNotification: false)
        case let .failure(error):
            guard error.code != 404 && error.code != 403 else {
                ConversationDAO.shared.clearConversation(conversationId: conversationId, exitConversation: true, autoNotification: false)
                return
            }
            throw error
        }
    }

}
