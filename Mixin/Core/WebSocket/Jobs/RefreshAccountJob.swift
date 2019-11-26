import Foundation

class RefreshAccountJob: BaseJob {

    override func getJobId() -> String {
        return "refresh-account-\(AccountAPI.shared.accountUserId)"
    }

    override func run() throws {
        guard AccountAPI.shared.didLogin else {
            return
        }
        switch AccountAPI.shared.me() {
        case let .success(account):
            AccountAPI.shared.updateAccount(account: account)
        case let .failure(error):
            throw error
        }
    }

}
