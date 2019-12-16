import Foundation

class RefreshUserJob: BaseJob {

    let userId: String
    let notifyConversation: Bool

    init(userId: String, notifyConversation: Bool = false) {
        self.userId = userId
        self.notifyConversation = notifyConversation
    }

    override func main() {
        guard !isCancelled, AccountAPI.shared.didLogin, !userId.isEmpty else {
            return
        }

        let notify = self.notifyConversation
        UserAPI.shared.showUser(userId: userId) { (result) in
            switch result {
            case let .success(response):
                UserDAO.shared.updateUser(user: response, notifyConversation: notify)
            case let .failure(error, didHandled):
                print("======RefreshUserOperation...error:\(error)...didHandled:\(didHandled)")
            }
        }
    }
}

