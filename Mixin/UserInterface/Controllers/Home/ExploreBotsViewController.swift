import UIKit
import MixinServices

final class ExploreBotsViewController: UITableViewController {
    
    private enum FixedSection: Int, CaseIterable {
        case actions = 0
        case favorites
    }
    
    private let headerReuseID = "header"
    private let actions: [ExploreAction] = [
        .camera, .linkDesktop, .customerService,
    ]
    
    private(set) var allUsers: [User]? = nil
    
    private var favoriteAppUsers: [User] = []
    private var indexTitles: [String]? = nil
    private var indexedUsers: [[User]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        tableView.separatorStyle = .none
        tableView.register(R.nib.exploreActionCell)
        tableView.register(R.nib.peerCell)
        tableView.register(PeerHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
        tableView.sectionIndexColor = R.color.text_tertiary()
        tableView.rowHeight = 70
        tableView.contentInset.bottom = 10
        reloadFavoriteAppsFromLocal()
        reloadFavoriteAppsFromRemote()
        reloadAllApps()
        let center: NotificationCenter = .default
        center.addObserver(self,
                           selector: #selector(reloadAllApps),
                           name: UserDAO.usersDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(reloadFavoriteAppsFromLocal),
                           name: UserDAO.usersDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(reloadFavoriteAppsFromLocal),
                           name: FavoriteAppsDAO.favoriteAppsDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateLinkDesktopAction),
                           name: AppGroupUserDefaults.Account.extensionSessionDidChangeNotification,
                           object: nil)
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        FixedSection.allCases.count + (indexTitles?.count ?? 0)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch FixedSection(rawValue: section) {
        case .actions:
            actions.count
        case .favorites:
            favoriteAppUsers.count
        default:
            indexedUsers(at: section).count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch FixedSection(rawValue: indexPath.section) {
        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.explore_action, for: indexPath)!
            let action = actions[indexPath.row]
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
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            let user = indexedUser(at: indexPath)
            cell.peerInfoView.render(user: user, description: .identityNumber)
            return cell
        }
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        indexTitles
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        index + FixedSection.allCases.count
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch FixedSection(rawValue: section) {
        case .actions:
            0
        default:
            34
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID) as! PeerHeaderView
        switch FixedSection(rawValue: section) {
        case .actions:
            return nil
        case .favorites:
            header.label.text = R.string.localizable.favorite()
            return header
        default:
            header.label.text = indexTitles?[section - FixedSection.allCases.count]
            return header
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let explore = parent as? ExploreViewController {
            let user = indexedUser(at: indexPath)
            explore.presentProfile(user: user)
        }
    }
    
    @objc private func reloadAllApps() {
        
        class ObjcAccessibleUser: NSObject {
            
            @objc let fullName: String
            let user: User
            
            init(user: User) {
                self.fullName = user.fullName ?? ""
                self.user = user
                super.init()
            }
            
        }
        
        DispatchQueue.global().async {
            let allUsers = UserDAO.shared.getAppUsers()
            let objcAccessibleUsers = allUsers.map(ObjcAccessibleUser.init(user:))
            let (titles, indexedObjcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let indexedUsers = indexedObjcUsers.map { $0.map(\.user) }
            DispatchQueue.main.async {
                self.allUsers = allUsers
                self.indexTitles = titles
                self.indexedUsers = indexedUsers
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: allUsers.count,
                                          text: R.string.localizable.no_bots(),
                                          photo: R.image.emptyIndicator.ic_data()!)
            }
        }
    }
    
    @objc private func reloadFavoriteAppsFromLocal() {
        DispatchQueue.global().async { [weak self] in
            let users = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.favoriteAppUsers = users
                let favorites = IndexSet(integer: FixedSection.favorites.rawValue)
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
    
    @objc private func updateLinkDesktopAction() {
        guard let row = actions.firstIndex(of: .linkDesktop) else {
            return
        }
        let indexPath = IndexPath(row: row, section: FixedSection.actions.rawValue)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    private func indexedUsers(at section: Int) -> [User] {
        indexedUsers[section - FixedSection.allCases.count]
    }
    
    private func indexedUser(at indexPath: IndexPath) -> User {
        indexedUsers(at: indexPath.section)[indexPath.row]
    }
    
}
