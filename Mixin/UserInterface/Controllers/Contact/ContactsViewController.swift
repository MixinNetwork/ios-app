import UIKit
import MixinServices

final class ContactsViewController: UIViewController {
    
    private let showAddContactButton: Bool
    private let searchBoxView = SearchBoxView()
    private let queue = OperationQueue()
    private let headerReuseIdentifier = "contact_header"
    
    private var collectionView: UICollectionView!
    private var sectionTitles: [String] = []
    private var contacts: [[UserItem]] = []
    private var searchResults: [UserSearchResult] = []
    private var searchingKeyword: String?
    private var searchOperation: BlockOperation?
    
    private var isSearching: Bool {
        searchingKeyword != nil
    }
    
    init(showAddContactButton: Bool) {
        self.showAddContactButton = showAddContactButton
        super.init(nibName: nil, bundle: nil)
        self.title = showAddContactButton ? R.string.localizable.contacts() : R.string.localizable.new_chat()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        queue.cancelAllOperations()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background_secondary()
        if showAddContactButton {
            navigationItem.rightBarButtonItem = .tintedIcon(
                image: R.image.ic_user_add_contact(),
                target: self,
                action: #selector(addContact(_:)),
            )
        }
        
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
            make.height.greaterThanOrEqualTo(40)
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
            let sectionCount = self.isSearching ? 1 : self.contacts.count
            section.contentInsets = NSDirectionalEdgeInsets(
                top: self.isSearching ? 20 : 0,
                leading: 16,
                bottom: sectionIndex == sectionCount - 1 ? 20 : 0,
                trailing: 16,
            )
            let corners: ExploreContactSectionBackgroundView.Corners
            if sectionCount == 1 {
                corners = .all
            } else if sectionIndex == 0 {
                corners = .top
            } else if sectionIndex == sectionCount - 1 {
                corners = .bottom
            } else {
                corners = .none
            }
            let background = NSCollectionLayoutDecorationItem.background(
                elementKind: corners.rawValue,
            )
            background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
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
        collectionView.tintColor = R.color.icon_tint_tertiary() // Index titles
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadContacts),
            name: UserDAO.usersDidChangeNotification,
            object: nil,
        )
        queue.maxConcurrentOperationCount = 1
        reloadContacts()
        ContactAPI.syncContacts()
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
    
    @objc private func addContact(_ sender: Any) {
        let controller = AddContactViewController()
        navigationController?.pushViewController(controller, animated: true)
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
    
    @objc private func reloadContacts() {
        class ObjcAccessibleUser: NSObject {
            @objc let fullName: String
            let user: UserItem
            
            init(user: UserItem) {
                self.fullName = user.fullName
                self.user = user
                super.init()
            }
        }
        queue.addOperation { [weak self] in
            let objcAccessibleUsers = UserDAO.shared
                .contactsWithoutApp(limit: nil)
                .map(ObjcAccessibleUser.init)
            let (titles, objcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let users = objcUsers.map({ $0.map({ $0.user }) })
            DispatchQueue.main.sync {
                guard let self else {
                    return
                }
                self.sectionTitles = titles
                self.contacts = users
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
        let users = contacts.flatMap({ $0 })
        operation.addExecutionBlock { [unowned operation, weak self] in
            guard !operation.isCancelled else {
                return
            }
            let results = users
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ UserSearchResult(user: $0, keyword: keyword) })
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
        if isSearching {
            collectionView.checkEmpty(
                dataCount: searchResults.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!,
            )
        } else {
            collectionView.checkEmpty(
                dataCount: contacts.count,
                text: R.string.localizable.no_contacts(),
                photo: R.image.emptyIndicator.ic_data()!,
            )
        }
    }
    
}

extension ContactsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        isSearching ? 1 : contacts.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int,
    ) -> Int {
        isSearching ? searchResults.count : contacts[section].count
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
            cell.load(result: searchResults[indexPath.item])
        } else {
            cell.load(user: contacts[indexPath.section][indexPath.item])
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
        isSearching ? nil : sectionTitles
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        indexPathForIndexTitle title: String,
        at index: Int,
    ) -> IndexPath {
        IndexPath(index: index)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let user: UserItem
        if isSearching {
            user = searchResults[indexPath.item].user
        } else {
            user = contacts[indexPath.section][indexPath.item]
        }
        let profile = UserProfileViewController(user: user)
        present(profile, animated: true, completion: nil)
    }
    
}
