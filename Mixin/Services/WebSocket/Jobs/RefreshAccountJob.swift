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
        let myId = AccountAPI.shared.accountUserId
        switch UserAPI.shared.getFavoriteApps(ofUserWith: myId) {
        case let .success(favApps):
            FavoriteAppsDAO.shared.updateFavoriteApps(favApps, forUserWith: myId)
        case let .failure(error):
            throw error
        }
    }

}
