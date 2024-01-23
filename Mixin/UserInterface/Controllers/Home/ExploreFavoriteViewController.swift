import UIKit
import MixinServices

final class ExploreFavoriteViewController: UITableViewController {
    
    private enum Section: Int {
        case fixed = 0
        case favorites = 1
    }
    
    private struct FixedItem {
        let icon: UIImage
        let title: String
        let subtitle: String
        let action: ExploreAction
    }
    
    private let fixedItems: [FixedItem] = [
        FixedItem(icon: R.image.explore.camera()!,
                  title: R.string.localizable.camera(),
                  subtitle: R.string.localizable.take_a_photo(),
                  action: .camera),
        FixedItem(icon: R.image.explore.link_desktop()!,
                  title: R.string.localizable.link_desktop(),
                  subtitle: R.string.localizable.link_desktop_description(),
                  action: .linkDesktop),
        FixedItem(icon: R.image.explore.customer_service()!,
                  title: R.string.localizable.contact_support(),
                  subtitle: R.string.localizable.leave_message_to_team_mixin(),
                  action: .contactSupport),
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
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .fixed:
            return fixedItems.count
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
            let item = fixedItems[indexPath.row]
            cell.iconTrayImageView.image = R.image.explore.action_tray()
            cell.iconImageView.image = item.icon
            cell.titleLabel.text = item.title
            cell.subtitleLabel.text = item.subtitle
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
                cell.iconTrayImageView.image = R.image.explore.edit_favorite_app()
                cell.iconImageView.image = nil
                cell.titleLabel.text = R.string.localizable.my_favorite_bots()
                cell.subtitleLabel.text = R.string.localizable.add_or_remove_favorite_bots()
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
            let item = fixedItems[indexPath.row]
            explore.perform(action: item.action)
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
