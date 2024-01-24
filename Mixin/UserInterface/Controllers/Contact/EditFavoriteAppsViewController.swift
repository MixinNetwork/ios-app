import UIKit
import MixinServices

final class EditFavoriteAppsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noAppIndicator: UIView!
    
    var favorites = [User]()
    var candidates = [User]()
    
    private let headerReuseID = "header"
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.contact.edit_favorite_apps()!
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.my_favorite_bots())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(EditFavoriteAppsHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
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
        if indexPath.section == 0 {
            let user = favorites.remove(at: indexPath.row)
            candidates.insert(user, at: 0)
        } else {
            let user = candidates.remove(at: indexPath.row)
            favorites.append(user)
        }
        tableView.reloadData()
        if favorites.isEmpty {
            tableView.contentInset.top = 20
        } else {
            tableView.contentInset.top = 10
        }
    }
    
}

extension EditFavoriteAppsViewController: UITableViewDataSource {
    
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

extension EditFavoriteAppsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1 {
            return UITableView.automaticDimension
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else {
            return nil
        }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID) as! EditFavoriteAppsHeaderView
        if favorites.isEmpty {
            view.descriptionWrapperViewTopConstraint.constant = 0
        } else {
            view.descriptionWrapperViewTopConstraint.constant = 20
        }
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
}

extension EditFavoriteAppsViewController: FavoriteAppCellDelegate {
    
    func favoriteAppCellDidSelectAccessoryButton(_ cell: FavoriteAppCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let hud = Hud()
        if indexPath.section == 0 {
            let user = favorites[indexPath.row]
            if let id = user.appId {
                hud.show(style: .busy, text: "", on: view)
                UserAPI.unfavoriteApp(id: id) { [weak self] (result) in
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
                UserAPI.setFavoriteApp(id: id) { [weak self] (result) in
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
