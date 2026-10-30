import UIKit
import MixinServices

final class BotsViewController: UIViewController {
    
    private let searchBoxView = SearchBoxView()
    private let queue = OperationQueue()
    private let headerReuseIdentifier = "bot_header"
    
    private var collectionView: UICollectionView!
    private var allUsers: [User] = []
    private var favoriteBotIDs: Set<String> = []
    private var sectionTitles: [String] = []
    private var users: [[User]] = []
    private var searchResults: [AppUserSearchResult] = []
    private var searchingKeyword: String?
    private var searchOperation: BlockOperation?
    
    private var isSearching: Bool {
        searchingKeyword != nil
    }
    
    deinit {
        queue.cancelAllOperations()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.bots_title()
        view.backgroundColor = R.color.background_secondary()
        searchBoxView.contentView.backgroundColor = R.color.background()
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        searchBoxView.textField.addTarget(
            self,
            action: #selector(textFieldEditingChanged(_:)),
            for: .editingChanged,
        )
        view.addSubview(searchBoxView)
        searchBoxView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(40)
        }
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else {
                return nil
            }
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(58),
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: itemSize,
                subitems: [item],
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 20
            let sectionCount = self.isSearching ? 1 : self.users.count
            let firstAlphabeticalSection = 1
            let isFavoriteSection = !self.isSearching && sectionIndex == 0
            let sectionSpacing: CGFloat = isFavoriteSection ? 10 : 0
            let bottomPadding: CGFloat = isFavoriteSection || sectionIndex == sectionCount - 1 ? 20 : 0
            section.contentInsets = NSDirectionalEdgeInsets(
                top: self.isSearching ? 20 : 0,
                leading: 16,
                bottom: bottomPadding + sectionSpacing,
                trailing: 16,
            )
            let corners: ExploreContactSectionBackgroundView.Corners
            if self.isSearching || isFavoriteSection || sectionCount - firstAlphabeticalSection == 1 {
                corners = .all
            } else if sectionIndex == firstAlphabeticalSection {
                corners = .top
            } else if sectionIndex == sectionCount - 1 {
                corners = .bottom
            } else {
                corners = .none
            }
            let background = NSCollectionLayoutDecorationItem.background(
                elementKind: corners.rawValue,
            )
            background.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 16,
                bottom: sectionSpacing,
                trailing: 16,
            )
            section.decorationItems = [background]
            if !self.isSearching {
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(36),
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                )
                section.boundarySupplementaryItems = [header]
            }
            return section
        }
        for corners in ExploreContactSectionBackgroundView.Corners.allCases {
            layout.register(
                ExploreContactSectionBackgroundView.self,
                forDecorationViewOfKind: corners.rawValue,
            )
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.tintColor = R.color.icon_tint_tertiary()
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.register(
            ExploreContactCell.self,
            forCellWithReuseIdentifier: ExploreContactCell.reuseIdentifier,
        )
        collectionView.register(
            UICollectionViewListCell.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: headerReuseIdentifier,
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(searchBoxView.snp.bottom).offset(10)
            make.leading.trailing.bottom.equalToSuperview()
        }
        collectionView.contentInset.top = 6
        
        for name in [
            UserDAO.usersDidChangeNotification,
            FavoriteAppsDAO.favoriteAppsDidChangeNotification,
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reloadBots),
                name: name,
                object: nil,
            )
        }
        queue.maxConcurrentOperationCount = 1
        reloadBots()
        UserAPI.getFavoriteApps(ofUserWith: myUserId) { result in
            guard case let .success(apps) = result else {
                return
            }
            DispatchQueue.global().async {
                FavoriteAppsDAO.shared.updateFavoriteApps(apps, forUserWith: myUserId)
                UserAPI.showUsers(userIds: apps.map(\.appId)) { result in
                    guard case let .success(users) = result else {
                        return
                    }
                    UserDAO.shared.updateUsers(users: users)
                }
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        for result in searchResults {
            result.updateTitleAndDescription()
        }
        if isSearching {
            collectionView.reloadData()
        }
    }
    
    @objc private func textFieldEditingChanged(_ textField: UITextField) {
        let keyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard keyword != searchingKeyword else {
            return
        }
        if keyword.isEmpty {
            searchOperation?.cancel()
            searchOperation = nil
            searchingKeyword = nil
            searchResults = []
            reloadData()
        } else {
            search(keyword: keyword)
        }
    }
    
    @objc private func reloadBots() {
        class ObjcAccessibleUser: NSObject {
            @objc let fullName: String
            let user: User
            
            init(user: User) {
                self.fullName = user.fullName ?? ""
                self.user = user
                super.init()
            }
        }
        queue.addOperation { [weak self] in
            let favorites = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            let favoriteBotIDs = Set(favorites.map(\.userId))
            let allUsers = UserDAO.shared.friendAppUsers(limit: nil)
            let objcAccessibleUsers = allUsers.map(ObjcAccessibleUser.init)
            let (titles, objcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let users = objcUsers.map({ $0.map(\.user) })
            DispatchQueue.main.sync {
                guard let self else {
                    return
                }
                self.allUsers = favorites + allUsers.filter { !favoriteBotIDs.contains($0.userId) }
                self.favoriteBotIDs = favoriteBotIDs
                self.sectionTitles = [R.string.localizable.favorite()] + titles
                self.users = [favorites] + users
                if let keyword = self.searchingKeyword {
                    self.search(keyword: keyword)
                } else {
                    self.reloadData()
                }
            }
        }
    }
    
    private func search(keyword: String) {
        searchOperation?.cancel()
        searchingKeyword = keyword
        searchResults = []
        reloadData()
        let operation = BlockOperation()
        let users = allUsers
        operation.addExecutionBlock { [unowned operation, weak self] in
            guard !operation.isCancelled else {
                return
            }
            let results = users
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ AppUserSearchResult(user: $0, keyword: keyword) })
            DispatchQueue.main.sync {
                guard let self, !operation.isCancelled, self.searchingKeyword == keyword else {
                    return
                }
                self.searchOperation = nil
                self.searchResults = results
                self.reloadData()
            }
        }
        searchOperation = operation
        queue.addOperation(operation)
    }
    
    private func reloadData() {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        collectionView.checkEmpty(
            dataCount: isSearching ? searchResults.count : allUsers.count + 1,
            text: R.string.localizable.no_bots(),
            photo: R.image.emptyIndicator.ic_data()!,
        )
    }
    
}

extension BotsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        isSearching ? 1 : users.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int,
    ) -> Int {
        if isSearching {
            searchResults.count
        } else {
            users[section].count + (section == 0 ? 1 : 0)
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath,
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ExploreContactCell.reuseIdentifier,
            for: indexPath,
        ) as! ExploreContactCell
        cell.peerInfoViewHeight = 50
        if isSearching {
            let result = searchResults[indexPath.item]
            cell.load(result: result, isFavorite: favoriteBotIDs.contains(result.user.userId))
        } else if indexPath.section == 0 && indexPath.item == users[0].count {
            cell.loadAsFavoriteAppManager()
        } else {
            cell.load(
                user: users[indexPath.section][indexPath.item],
                externalIndicator: indexPath.section == 0,
            )
        }
        return cell
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: headerReuseIdentifier,
            for: indexPath,
        ) as! UICollectionViewListCell
        var content = UIListContentConfiguration.plainHeader()
        content.text = sectionTitles[indexPath.section]
        content.textProperties.font = .scaledFont(ofSize: 14, weight: .regular)
        content.textProperties.color = R.color.text()!
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 20,
            leading: 16,
            bottom: 20,
            trailing: 16,
        )
        header.contentConfiguration = content
        header.backgroundConfiguration = .clear()
        return header
    }
    
    func indexTitles(for collectionView: UICollectionView) -> [String]? {
        guard !isSearching else {
            return nil
        }
        return Array(sectionTitles.dropFirst())
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        indexPathForIndexTitle title: String,
        at index: Int,
    ) -> IndexPath {
        IndexPath(index: index + 1)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if !isSearching && indexPath.section == 0 && indexPath.item == users[0].count {
            let editor = EditFavoriteAppsViewController()
            navigationController?.pushViewController(editor, animated: true)
            return
        }
        let user: User
        let isFavorite: Bool
        if isSearching {
            user = searchResults[indexPath.item].user
            isFavorite = favoriteBotIDs.contains(user.userId)
        } else {
            user = users[indexPath.section][indexPath.item]
            isFavorite = indexPath.section == 0
        }
        if isFavorite {
            guard let app = AppDAO.shared.getApp(ofUserId: user.userId) else {
                return
            }
            AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
            let appHome = MixinWebViewController(
                context: .init(conversationID: "", app: app, isAppVerified: user.isVerified),
            )
            navigationController?.pushViewController(appHome, animated: true)
        } else {
            let item = UserItem.createUser(from: user)
            let profile = UserProfileViewController(user: item)
            present(profile, animated: true, completion: nil)
        }
    }
    
}
