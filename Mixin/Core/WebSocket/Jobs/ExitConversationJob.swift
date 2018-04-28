import Foundation

class ExitConversationJob: BaseJob {

    let conversationId: String

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    override func getJobId() -> String {
        return "exit-coversation-\(conversationId)"
    }

    override func shouldRetry(error: JobError) -> Bool {
        if case let .clientError(code) = error, (code == 404 || code == 403) {
            ConversationDAO.shared.deleteAndExitConversation(conversationId: conversationId, autoNotification: false)
            return false
        } else {
            return super.shouldRetry(error: error)
        }
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
            throw error
        }
    }

}
