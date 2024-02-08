import UIKit
import MixinServices

final class ExploreFavoriteViewController: UITableViewController {
    
    private enum Section: Int {
        case fixed = 0
        case favorites = 1
    }
    
    private let fixedActions: [ExploreAction] = [
        .camera, .linkDesktop, .customerService,
    ]
    
    private var favoriteAppUsers: [User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        tableView.separatorStyle = .none
        tableView.register(R.nib.exploreActionCell)
        tableView.register(R.nib.peerCell)
        tableView.register(SeparatorHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: SeparatorHeaderFooterView.reuseIdentifier)
        tableView.rowHeight = 70
        tableView.contentInset.bottom = 10
        reloadFavoriteAppsFromLocal()
        reloadFavoriteAppsFromRemote()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadFavoriteAppsFromLocal), name: UserDAO.usersDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadFavoriteAppsFromLocal), name: FavoriteAppsDAO.favoriteAppsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLinkDesktopAction), name: AppGroupUserDefaults.Account.extensionSessionDidChangeNotification, object: nil)
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .fixed:
            return fixedActions.count
        case .favorites:
            return favoriteAppUsers.count + 1
        case nil:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .fixed:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.explore_action, for: indexPath)!
            let action = fixedActions[indexPath.row]
            cell.load(action: action)
            return cell
        case .favorites:
            if indexPath.row < favoriteAppUsers.count {
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
                let user = favoriteAppUsers[indexPath.row]
                cell.peerInfoView.render(user: user, description: .identityNumber)
                cell.peerInfoView.avatarImageView.hasShadow = false
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.explore_action, for: indexPath)!
                cell.load(action: .editFavoriteApps)
                return cell
            }
        }
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .favorites:
            return 50
        case .fixed, nil:
            return .leastNormalMagnitude
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section) {
        case .favorites:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: SeparatorHeaderFooterView.reuseIdentifier)
            headerView?.backgroundColor = R.color.background()
            return headerView
        case .fixed, nil:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let explore = parent as? ExploreViewController else {
            return
        }
        switch Section(rawValue: indexPath.section) {
        case .fixed:
            let action = fixedActions[indexPath.row]
            explore.perform(action: action)
        case .favorites:
            if indexPath.row < favoriteAppUsers.count {
                let user = favoriteAppUsers[indexPath.row]
                explore.presentProfile(user: user)
            } else {
                explore.perform(action: .editFavoriteApps)
            }
        case nil:
            break
        }
    }
    
    // MARK: - Data Loader
    @objc private func updateLinkDesktopAction() {
        guard let row = fixedActions.firstIndex(of: .linkDesktop) else {
            return
        }
        let indexPath = IndexPath(row: row, section: Section.fixed.rawValue)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    @objc private func reloadFavoriteAppsFromLocal() {
        DispatchQueue.global().async { [weak self] in
            let users = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.favoriteAppUsers = users
                let favorites = IndexSet(integer: Section.favorites.rawValue)
                UIView.performWithoutAnimation {
                    self.tableView.reloadSections(favorites, with: .none)
                }
            }
        }
    }
    
    private func reloadFavoriteAppsFromRemote() {
        UserAPI.getFavoriteApps(ofUserWith: myUserId) { (result) in
            guard case let .success(apps) = result else {
                return
            }
            DispatchQueue.global().async {
                FavoriteAppsDAO.shared.updateFavoriteApps(apps, forUserWith: myUserId)
                let appUserIds = apps.map({ $0.appId })
                UserAPI.showUsers(userIds: appUserIds) { (result) in
                    guard case let .success(users) = result else {
                        return
                    }
                    UserDAO.shared.updateUsers(users: users)
                }
            }
        }
    }
    
}
