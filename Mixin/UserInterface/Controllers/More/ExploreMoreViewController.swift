import UIKit
import MixinServices

final class ExploreMoreViewController: UIViewController, AssetChangeAccountRecoveryChecking {
    
    private enum Section: Int, CaseIterable {
        case account
        case actions
        case contacts
        case bots
    }
    
    private let actions: [ExploreMoreAction] = [
        .buy, .trade, .membership, .referral, .linkDesktop, .customerService,
    ]
    private let contactsLimit = 3
    private let botsLimit = 5
    private let dataQueue = DispatchQueue(
        label: "one.mixin.explore.data",
        qos: .userInitiated,
    )
    
    private var collectionView: UICollectionView!
    
    private var contacts: [UserItem] = []
    private var contactsCount = 0
    private var hasMoreContacts = false
    
    private var bots: [User] = []
    private var botsCount = 0
    private var hasMoreBots = false
    private var favoriteBotsCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel()
        titleLabel.text = R.string.localizable.more()
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = R.color.text()
        let titleItem = UIBarButtonItem(customView: titleLabel)
        if #available(iOS 26.0, *) {
            titleItem.hidesSharedBackground = true
        }
        navigationItem.leftBarButtonItem = titleItem
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_sticker_setting(),
                target: self,
                action: #selector(openSettings(_:)),
            ),
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_app_category_scan(),
                target: self,
                action: #selector(scanQRCode(_:)),
            ),
            UIBarButtonItem.tintedIcon(
                image: R.image.ic_title_search(),
                target: self,
                action: #selector(search(_:)),
            ),
        ]
        view.backgroundColor = R.color.background_secondary()
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let section = Section(rawValue: sectionIndex) else {
                return nil
            }
            switch section {
            case .account:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(64),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 16, bottom: 2, trailing: 16)
                return section
            case .actions:
                let heightDimension: NSCollectionLayoutDimension
                if #available(iOS 17.0, *) {
                    heightDimension = .uniformAcrossSiblings(estimate: 77)
                } else {
                    heightDimension = .estimated(77)
                }
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: heightDimension,
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: itemSize,
                    subitem: item,
                    count: 2,
                )
                group.interItemSpacing = .fixed(12)
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16)
                return section
            case .contacts:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(50),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                section.interGroupSpacing = 20
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(56),
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                )
                section.boundarySupplementaryItems = [header]
                if let self, self.hasMoreContacts {
                    let footer = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(56),
                        ),
                        elementKind: UICollectionView.elementKindSectionFooter,
                        alignment: .bottom,
                    )
                    section.boundarySupplementaryItems.append(footer)
                } else if let self, !self.contacts.isEmpty {
                    section.contentInsets.bottom = 20
                }
                let background = NSCollectionLayoutDecorationItem.background(
                    elementKind: TradeSectionBackgroundView.elementKind,
                )
                background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                section.decorationItems = [background]
                return section
            case .bots:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(50),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                section.interGroupSpacing = 20
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(56),
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                )
                section.boundarySupplementaryItems = [header]
                if let self, self.hasMoreBots {
                    let footer = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(56),
                        ),
                        elementKind: UICollectionView.elementKindSectionFooter,
                        alignment: .bottom,
                    )
                    section.boundarySupplementaryItems.append(footer)
                } else if let self, !self.bots.isEmpty {
                    section.contentInsets.bottom = 20
                }
                let background = NSCollectionLayoutDecorationItem.background(
                    elementKind: TradeSectionBackgroundView.elementKind,
                )
                background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                section.decorationItems = [background]
                return section
            }
        }
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = 10
        layout.configuration = configuration
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind,
        )
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.alwaysBounceVertical = true
        collectionView.register(R.nib.userCenterCell)
        collectionView.register(R.nib.exploreMoreActionCell)
        collectionView.register(
            ExploreContactCell.self,
            forCellWithReuseIdentifier: ExploreContactCell.reuseIdentifier,
        )
        collectionView.register(
            R.nib.tradeSectionHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
        )
        collectionView.register(
            ExploreMoreFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: ExploreMoreFooterView.reuseIdentifier,
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }
        collectionView.contentInset.bottom = 10
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cancelSearchingSilently),
            name: dismissSearchNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadAccount),
            name: LoginManager.accountDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadContacts),
            name: UserDAO.usersDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadBots),
            name: UserDAO.usersDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadBots),
            name: FavoriteAppsDAO.favoriteAppsDidChangeNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadActions),
            name: BadgeManager.viewedNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadActions),
            name: AppGroupUserDefaults.Account.extensionSessionDidChangeNotification,
            object: nil,
        )
        reloadContacts()
        reloadBots()
        ContactAPI.syncContacts()
        UserAPI.getFavoriteApps(ofUserWith: myUserId) { [weak self] result in
            guard case let .success(apps) = result else {
                return
            }
            DispatchQueue.global().async { [weak self] in
                FavoriteAppsDAO.shared.updateFavoriteApps(apps, forUserWith: myUserId)
                self?.reloadBots()
                UserAPI.showUsers(userIds: apps.map(\.appId)) { result in
                    guard case let .success(users) = result else {
                        return
                    }
                    UserDAO.shared.updateUsers(users: users)
                }
            }
        }
    }
    
    @IBAction func search(_ sender: Any) {
        let searchViewController = ExploreAggregatedSearchViewController()
        navigationController?.pushViewController(searchViewController, animated: true)
    }
    
    @IBAction func scanQRCode(_ sender: Any) {
        UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
    }
    
    @IBAction func openSettings(_ sender: Any) {
        let settings = SettingsViewController()
        navigationController?.pushViewController(settings, animated: true)
    }
    
    @objc func cancelSearching(_ sender: Any) {
        navigationController?.popToViewController(self, animated: true)
    }
    
}

extension ExploreMoreViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .account:
            1
        case .actions:
            actions.count
        case .contacts:
            contacts.count
        case .bots:
            bots.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .account:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.user_center, for: indexPath)!
            if let account = LoginManager.shared.account {
                cell.load(account: account)
            }
            return cell
        case .actions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_more_action, for: indexPath)!
            cell.load(action: actions[indexPath.item])
            return cell
        case .contacts:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ExploreContactCell.reuseIdentifier,
                for: indexPath,
            ) as! ExploreContactCell
            cell.load(user: contacts[indexPath.item])
            return cell
        case .bots:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ExploreContactCell.reuseIdentifier,
                for: indexPath,
            ) as! ExploreContactCell
            let user = bots[indexPath.item]
            cell.load(
                user: user,
                externalIndicator: indexPath.item < favoriteBotsCount,
            )
            return cell
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: R.reuseIdentifier.trade_section_header,
                for: indexPath,
            )!
            let isSectionEmpty: Bool
            switch Section(rawValue: indexPath.section) {
            case .contacts:
                isSectionEmpty = contacts.isEmpty
                header.titleLabel.text = R.string.localizable.contact_title()
                header.subtitleLabel.text = contactsCount.formatted()
                header.onShowAll = { [weak self] _ in
                    self?.showContacts()
                }
            case .bots:
                isSectionEmpty = bots.isEmpty
                header.titleLabel.text = R.string.localizable.bots_title()
                header.subtitleLabel.text = botsCount.formatted()
                header.onShowAll = { [weak self] _ in
                    self?.showBots()
                }
            default:
                isSectionEmpty = false
            }
            header.contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            if isSectionEmpty {
                header.contentView.layer.maskedCorners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
            }
            header.subtitleLabel.textColor = R.color.text_tertiary()
            header.disclosureImageView.isHidden = false
            return header
        } else {
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ExploreMoreFooterView.reuseIdentifier,
                for: indexPath,
            ) as! ExploreMoreFooterView
            footer.onViewAll = { [weak self] _ in
                switch Section(rawValue: indexPath.section) {
                case .contacts:
                    self?.showContacts()
                case .bots:
                    self?.showBots()
                default:
                    break
                }
            }
            return footer
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .account:
            navigationController?.pushViewController(UserCenterViewController(), animated: true)
        case .actions:
            perform(action: actions[indexPath.item])
        case .contacts:
            let conversation = ConversationViewController.instance(ownerUser: contacts[indexPath.item])
            navigationController?.pushViewController(conversation, animated: true)
        case .bots:
            let user = bots[indexPath.item]
            if indexPath.item < favoriteBotsCount {
                openApp(user: user)
            } else {
                presentProfile(user: user)
            }
        }
    }
    
}

extension ExploreMoreViewController {
    
    private final class ExploreMoreFooterView: UICollectionReusableView {
        
        static let reuseIdentifier = "explore_more_footer"
        
        var onViewAll: ((UIView) -> Void)?
        
        private(set) weak var viewAllButton: UIButton!
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            addSubviews()
        }
        
        @objc private func viewAll(_ sender: UIButton) {
            onViewAll?(self)
        }
        
        private func addSubviews() {
            backgroundColor = R.color.background()
            layer.cornerRadius = 8
            layer.masksToBounds = true
            
            var config: UIButton.Configuration = .plain()
            config.titleAlignment = .center
            config.baseForegroundColor = R.color.theme()
            config.attributedTitle = AttributedString(
                string: R.string.localizable.view_all(),
                scalingByFontSize: 14,
                weight: .medium
            )
            let viewAllButton = UIButton(configuration: config)
            addSubview(viewAllButton)
            viewAllButton.snp.makeConstraints { make in
                make.height.width.greaterThanOrEqualTo(56)
                make.centerX.equalToSuperview()
                make.top.equalToSuperview()
            }
            viewAllButton.addTarget(self, action: #selector(viewAll(_:)), for: .touchUpInside)
            self.viewAllButton = viewAllButton
        }
        
    }
    
    @objc private func cancelSearchingSilently(_ notification: Notification) {
        guard let navigationController else {
            return
        }
        let viewControllers = navigationController.viewControllers.filter {
            !($0 is ExploreSearchViewController)
        }
        guard viewControllers.count != navigationController.viewControllers.count else {
            return
        }
        navigationController.setViewControllers(viewControllers, animated: false)
    }
    
    @objc private func reloadAccount() {
        reload(section: .account)
    }
    
    @objc private func reloadActions() {
        reload(section: .actions)
    }
    
    @objc private func reloadContacts() {
        dataQueue.async { [weak self] in
            guard let self else {
                return
            }
            let contacts = UserDAO.shared.contactsWithoutApp(limit: contactsLimit)
            let count = UserDAO.shared.contactsWithoutAppCount()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.contacts = contacts
                self.contactsCount = count
                self.hasMoreContacts = count > contactsLimit
                self.reload(section: .contacts)
            }
        }
    }
    
    @objc private func reloadBots() {
        dataQueue.async { [weak self, botsLimit] in
            guard let self else {
                return
            }
            let favorites = FavoriteAppsDAO.shared.favoriteAppUsersOfUser(withId: myUserId)
            let bots = if favorites.count < botsLimit {
                favorites + UserDAO.shared.appUsers(limit: botsLimit - favorites.count)
            } else {
                favorites
            }
            let count = UserDAO.shared.appUsersCount()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.bots = bots
                self.botsCount = count
                self.hasMoreBots = count > botsLimit
                self.favoriteBotsCount = favorites.count
                self.reload(section: .bots)
            }
        }
    }
    
    private func perform(action: ExploreMoreAction) {
        switch action {
        case .buy:
            let buy = BuyTokenInputAmountViewController(wallet: .privacy)
            navigationController?.pushViewController(buy, animated: true)
            BadgeManager.shared.setHasViewed(identifier: .buy)
            reporter.report(event: .buyStart, tags: ["wallet": "main", "source": "explore"])
        case .trade:
            BadgeManager.shared.setHasViewed(identifier: .trade)
            UserOperationAnalytics.tradeSource = .moreExplore
            let trade = TradeViewController(
                wallet: .privacy,
                trading: nil,
                sendAssetID: nil,
                receiveAssetID: nil,
                referral: nil
            )
            guard let trade else {
                return
            }
            withAccountRecoveryChecked { [weak self] in
                self?.navigationController?.pushViewController(trade, animated: true)
            }
        case .membership:
            if let membership = LoginManager.shared.account?.membership, let plan = membership.plan {
                let membership = MembershipViewController(plan: plan, expiredAt: membership.expiredAt)
                navigationController?.pushViewController(membership, animated: true)
            } else {
                let buy = MembershipPlansViewController(selectedPlan: nil)
                present(buy, animated: true)
            }
            BadgeManager.shared.setHasViewed(identifier: .membership)
        case .referral:
            UIApplication.shared.homeNavigationController?.presentReferralPage()
            BadgeManager.shared.setHasViewed(identifier: .referral)
        case .linkDesktop:
            let desktop = DesktopViewController()
            navigationController?.pushViewController(desktop, animated: true)
        case .customerService:
            let customerService = CustomerServiceViewController(reportingTags: nil)
            present(customerService, animated: true)
        }
    }
    
    private func presentProfile(user: User) {
        let item = UserItem.createUser(from: user)
        let profile = UserProfileViewController(user: item)
        present(profile, animated: true, completion: nil)
    }
    
    private func openApp(user: User) {
        guard let app = AppDAO.shared.getApp(ofUserId: user.userId) else {
            return
        }
        AppGroupUserDefaults.User.insertRecentlyUsedAppId(id: app.appId)
        let web = MixinWebViewController(context: .init(conversationID: "", app: app, isAppVerified: user.isVerified))
        navigationController?.pushViewController(web, animated: true)
    }
    
    private func showContacts() {
        let contacts = ContactsViewController(showAddContactButton: true)
        navigationController?.pushViewController(contacts, animated: true)
    }
    
    private func showBots() {
        let bots = BotsViewController()
        bots.title = R.string.localizable.bots_title()
        navigationController?.pushViewController(bots, animated: true)
    }
    
    private func reload(section: Section) {
        UIView.performWithoutAnimation {
            let sections = IndexSet(integer: section.rawValue)
            collectionView.reloadSections(sections)
        }
    }
    
}
