import Foundation
import MixinServices

class InitializeBotJob: BaseJob {
    
    let userID: String
    
    init(userID: String) {
        self.userID = userID
    }
    
    override func getJobId() -> String {
        "initialize-bot-\(userID)"
    }
    
    override func run() throws {
        guard !userID.isEmpty, UUID(uuidString: userID) != nil else {
            assertionFailure("Invalid user id")
            return
        }
        switch UserAPI.addFriend(userId: userID, fullName: nil) {
        case let .success(botUser):
            UserDAO.shared.updateUsers(users: [botUser])
        case let .failure(error):
            throw error
        }
    }
    
}
