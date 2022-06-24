import Foundation
import MixinServices

final class InitializeBotJob: BaseJob {
    
    struct Bot {
        let userId: String
        let fullname: String
    }
    
    private let bot: Bot
    
    init(bot: Bot) {
        self.bot = bot
    }
    
    override func getJobId() -> String {
        "initialize-bot-\(bot.userId)"
    }
    
    override func run() throws {
        guard !bot.userId.isEmpty, UUID(uuidString: bot.userId) != nil else {
            return
        }
        switch UserAPI.addFriend(userId: bot.userId, fullName: bot.fullname) {
        case let .success(botUser):
            UserDAO.shared.updateUsers(users: [botUser])
        case let .failure(error):
            throw error
        }
    }
    
}
