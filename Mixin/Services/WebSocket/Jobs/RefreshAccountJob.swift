import Foundation

class RefreshAccountJob: BaseJob {

    override func getJobId() -> String {
        return "refresh-account-\(myUserId)"
    }

    override func run() throws {
        guard isLoggedIn else {
            return
        }
        switch AccountAPI.shared.me() {
        case let .success(account):
            Account.current = account
        case let .failure(error):
            throw error
        }
        let myId = myUserId
        switch UserAPI.shared.getFavoriteApps(ofUserWith: myId) {
        case let .success(favApps):
            FavoriteAppsDAO.shared.updateFavoriteApps(favApps, forUserWith: myId)
        case let .failure(error):
            throw error
        }
    }

}
