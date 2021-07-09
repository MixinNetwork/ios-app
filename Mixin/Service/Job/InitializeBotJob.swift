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
            UserDAO.shared.updateUsers(users: [botUser])
        case let .failure(error):
            throw error
        }
    }
    
}
