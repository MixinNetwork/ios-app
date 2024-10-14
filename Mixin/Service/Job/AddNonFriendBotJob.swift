import UIKit
import MixinServices

final class AddBotIfNotFriendJob: InitializeBotJob {
    
    override func run() throws {
        let relationship = UserDAO.shared.relationship(id: userID)
        switch relationship {
        case .ME, .FRIEND:
            break
        case .STRANGER, .BLOCKING, .none:
            try super.run()
        }
    }
    
}
