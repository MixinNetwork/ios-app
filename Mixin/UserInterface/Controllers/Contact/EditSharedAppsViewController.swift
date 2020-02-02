import UIKit
import MixinServices

class EditSharedAppsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noAppIndicator: UIView!
    
    var favorites = [User]()
    var candidates = [User]()
    
    private let footerReuseId = "footer"
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.contact.edit_shared_apps()!
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.profile_my_shared_apps())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(EditSharedAppsFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        DispatchQueue.global().async {
            let favorites = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            let candidates = UserDAO.shared.appFriends(notIn: favorites.compactMap({ $0.userId }))
            DispatchQueue.main.async {
                if favorites.isEmpty && candidates.isEmpty {
                    self.noAppIndicator.isHidden = false
                } else {
                    self.favorites = favorites
                    self.candidates = candidates
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    private func toggleSection(forCellAt indexPath: IndexPath) {
        let newIndexPath: IndexPath
        let favoritesWereEmpty = favorites.isEmpty
        let candidatesWereEmpty = candidates.isEmpty
        if indexPath.section == 0 {
            let user = favorites.remove(at: indexPath.row)
            candidates.insert(user, at: 0)
            newIndexPath = IndexPath(row: 0, section: 1)
        } else {
            let user = candidates.remove(at: indexPath.row)
            favorites.append(user)
            newIndexPath = IndexPath(row: favorites.count - 1, section: 0)
        }
        if favoritesWereEmpty != favorites.isEmpty || candidatesWereEmpty != candidates.isEmpty {
            tableView.reloadData()
        } else {
            tableView.moveRow(at: indexPath, to: newIndexPath)
            tableView.reloadRows(at: [newIndexPath], with: .automatic)
        }
    }
    
}

extension EditSharedAppsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? favorites.count : candidates.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.favorite_app, for: indexPath)!
        if indexPath.section == 0 {
            cell.render(user: favorites[indexPath.row])
            cell.isFavorite = true
        } else {
            cell.render(user: candidates[indexPath.row])
            cell.isFavorite = false
        }
        cell.delegate = self
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
}

extension EditSharedAppsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            if favorites.isEmpty {
                return .leastNormalMagnitude
            } else {
                return 40
            }
        } else {
            return ScreenSize.current >= .inch5_8 ? 41 : 61
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! EditSharedAppsFooterView
        if section == 0 {
            if favorites.isEmpty {
                return nil
            } else {
                if candidates.isEmpty {
                    view.text = R.string.localizable.profile_share_app_hint()
                    view.style = .candidate
                } else {
                    view.text = nil
                    view.style = .favorite
                }
                return view
            }
        } else {
            view.text = R.string.localizable.profile_share_app_hint()
            view.style = .candidate
            if candidates.isEmpty {
                return nil
            } else {
                return view
            }
        }
    }
    
}

extension EditSharedAppsViewController: FavoriteAppCellDelegate {
    
    func favoriteAppCellDidSelectAccessoryButton(_ cell: FavoriteAppCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let hud = Hud()
        if indexPath.section == 0 {
            let user = favorites[indexPath.row]
            if let id = user.appId {
                hud.show(style: .busy, text: "", on: view)
                UserAPI.shared.unfavoriteApp(id: id) { [weak self] (result) in
                    switch result {
                    case .success:
                        self?.toggleSection(forCellAt: indexPath)
                        hud.hide()
                        DispatchQueue.global().async {
                            FavoriteAppsDAO.shared.unfavoriteApp(of: user.userId)
                        }
                    case .failure(let error):
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
            }
        } else {
            let user = candidates[indexPath.row]
            if let id = user.appId {
                hud.show(style: .busy, text: "", on: view)
                UserAPI.shared.setFavoriteApp(id: id) { [weak self] (result) in
                    switch result {
                    case .success(let favApp):
                        self?.toggleSection(forCellAt: indexPath)
                        hud.hide()
                        DispatchQueue.global().async {
                            FavoriteAppsDAO.shared.setFavoriteApp(favApp)
                        }
                    case .failure(let error):
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
            }
        }
    }
    
}
