import Foundation

internal class ExitConversationJob: BaseJob {

    let conversationId: String

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    override func getJobId() -> String {
        return "exit-coversation-\(conversationId)"
    }

    override func run() throws {
        let conversationId = self.conversationId
        guard !isCancelled, !conversationId.isEmpty, ConversationDAO.shared.getConversationStatus(conversationId: conversationId) == ConversationStatus.QUIT.rawValue else {
            return
        }

        switch ConversationAPI.shared.exitConversation(conversationId: conversationId) {
        case .success:
            ConversationDAO.shared.deleteAndExitConversation(conversationId: conversationId, autoNotification: false)
        case let .failure(error):
            guard error.code != 404 && error.code != 403 else {
                ConversationDAO.shared.deleteAndExitConversation(conversationId: conversationId, autoNotification: false)
                return
            }
            throw error
        }
    }

}
