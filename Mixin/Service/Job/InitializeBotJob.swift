import Foundation
import MixinServices

class InitializeBotJob: BaseJob {
    
    let botUserId: String
    let botFullname: String
    
    init(botUserId: String, botFullname: String) {
        self.botUserId = botUserId
        self.botFullname = botFullname
    }
    
    override func getJobId() -> String {
        return "initialize-bot"
    }
    
    override func run() throws {
        guard !botUserId.isEmpty, UUID(uuidString: botUserId) != nil else {
            return
        }
        switch UserAPI.addFriend(userId: botUserId, fullName: botFullname) {
        case let .success(botUser):
            guard let botUserItem = UserDAO.shared.saveUser(user: botUser) else {
                return
            }
            let conversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: botUserId)
            var message = Message.createMessage(category: MessageCategory.PLAIN_TEXT.rawValue,
                                                conversationId: conversationId,
                                                userId: myUserId)
            message.content = R.string.localizable.hi()
            SendMessageService.shared.sendMessage(message: message, ownerUser: botUserItem, isGroupMessage: false)
        case let .failure(error):
            throw error
        }
    }
    
}
