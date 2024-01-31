import UIKit
import MixinServices

final class EditFavoriteAppsViewController: PeerViewController<[User], FavoriteAppCell, AppUserSearchResult> {
    
    private enum Section: Int, CaseIterable {
        case favorite = 0
        case candidate = 1
    }
    
    override class var tableViewStyle: UITableView.Style {
        .grouped
    }
    
    private let headerReuseID = "header"
    
    private var hasData: Bool {
        if isSearching {
            !searchResults[Section.favorite.rawValue].isEmpty || !searchResults[Section.candidate.rawValue].isEmpty
        } else {
            !models[Section.favorite.rawValue].isEmpty || !models[Section.candidate.rawValue].isEmpty
        }
    }
    
    class func instance() -> UIViewController {
        let editor = EditFavoriteAppsViewController()
        return ContainerViewController.instance(viewController: editor, title: R.string.localizable.my_favorite_bots())
    }
    
    override func viewDidLoad() {
        models = [[User]](repeating: [], count: Section.allCases.count)
        searchResults = [[AppUserSearchResult]](repeating: [], count: Section.allCases.count)
        super.viewDidLoad()
        tableView.rowHeight = 70
        tableView.estimatedSectionHeaderHeight = 94
        tableView.register(EditFavoriteAppsHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
        tableView.allowsSelection = false
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
    }
    
    override func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            let favorites = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            let candidates = UserDAO.shared.appFriends(notIn: favorites.map(\.userId))
            DispatchQueue.main.sync {
                guard let self else {
                    return
                }
                self.models = [favorites, candidates]
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: favorites.count + candidates.count,
                                          text: R.string.localizable.no_bots() + "\n" + R.string.localizable.profile_share_bot_hint(),
                                          photo: R.image.emptyIndicator.ic_data()!)
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    override func stopSearching() {
        super.stopSearching()
        tableView.checkEmpty(dataCount: models[Section.favorite.rawValue].count + models[Section.candidate.rawValue].count,
                             text: R.string.localizable.no_bots() + "\n" + R.string.localizable.profile_share_bot_hint(),
                             photo: R.image.emptyIndicator.ic_data()!)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let models = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            var allResultsCount: Int = 0
            let searchResults = models.map { users in
                users.compactMap { user in
                    if user.matches(lowercasedKeyword: keyword) {
                        allResultsCount += 1
                        return AppUserSearchResult(user: user, keyword: keyword)
                    } else {
                        return nil
                    }
                }
            }
            DispatchQueue.main.sync {
                guard let self, !op.isCancelled else {
                    return
                }
                self.searchingKeyword = keyword
                self.searchResults = searchResults
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: allResultsCount,
                                          text: R.string.localizable.no_results(),
                                          photo: R.image.emptyIndicator.ic_search_result()!)
            }
        }
        queue.addOperation(op)
    }
    
    override func configure(cell: FavoriteAppCell, at indexPath: IndexPath) {
        if isSearching {
            cell.render(result: searchResults[indexPath.section][indexPath.row])
        } else {
            cell.render(user: models[indexPath.section][indexPath.row])
        }
        cell.isFavorite = Section(rawValue: indexPath.section) == .favorite
        cell.delegate = self
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isSearching ? searchResults[section].count : models[section].count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .candidate && hasData {
            UITableView.automaticDimension
        } else {
            .leastNormalMagnitude
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .candidate && hasData else {
            return nil
        }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID) as! EditFavoriteAppsHeaderView
        let numberOfFavorites = if isSearching {
            searchResults[Section.favorite.rawValue].count
        } else {
            models[Section.favorite.rawValue].count
        }
        if numberOfFavorites == 0 {
            view.descriptionWrapperViewTopConstraint.constant = 0
        } else {
            view.descriptionWrapperViewTopConstraint.constant = 20
        }
        return view
    }
    
    private func toggleSection(forCellAt indexPath: IndexPath) {
        
        func toggleSection<Model>(forModelAt indexPath: IndexPath, models: inout [[Model]]) {
            if Section(rawValue: indexPath.section) == .favorite {
                let user = models[Section.favorite.rawValue].remove(at: indexPath.row)
                models[Section.candidate.rawValue].insert(user, at: 0)
            } else {
                let user = models[Section.candidate.rawValue].remove(at: indexPath.row)
                models[Section.favorite.rawValue].append(user)
            }
        }
        
        if isSearching {
            let userID = searchResults[indexPath.section][indexPath.row].user.userId
            toggleSection(forModelAt: indexPath, models: &searchResults)
            if let row = models[indexPath.section].firstIndex(where: { $0.userId == userID }) {
                let modelIndexPath = IndexPath(row: row, section: indexPath.section)
                toggleSection(forModelAt: modelIndexPath, models: &models)
            }
        } else {
            toggleSection(forModelAt: indexPath, models: &models)
        }
        tableView.reloadData()
        if models[Section.favorite.rawValue].isEmpty {
            tableView.contentInset.top = 20
        } else {
            tableView.contentInset.top = 10
        }
    }
    
}

extension EditFavoriteAppsViewController: FavoriteAppCellDelegate {
    
    func favoriteAppCellDidSelectAccessoryButton(_ cell: FavoriteAppCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let hud = Hud()
        let user = if isSearching {
            searchResults[indexPath.section][indexPath.row].user
        } else {
            models[indexPath.section][indexPath.row]
        }
        switch Section(rawValue: indexPath.section)! {
        case .favorite:
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
        case .candidate:
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
