import UIKit
import SafariServices
import OrderedCollections
import MixinServices

final class WalletSummaryViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case summary
        case walletCategories
        case wallets
        case tips
        case tipsPageControl
    }
    
    private enum ReuseIdentifier {
        static let pageControl = "p"
        static let loading = "l"
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addWalletView: BadgeBarButtonView!
    
    private var summary: WalletSummary?
    private var digests: OrderedDictionary<WalletDisplayCategory, [WalletDigest]> = [:]
    private var tips: [WalletTipCell.Content] = []
    private var secretAvailableWalletIDs: Set<String> = []
    private var unexpiredPlan: User.Membership.Plan?
    private var isLoadingSafeWallets = true
    
    private var selectedCategory = WalletDisplayCategory(rawValue: AppGroupUserDefaults.Wallet.lastSelectedCategory) ?? .all {
        didSet {
            AppGroupUserDefaults.Wallet.lastSelectedCategory = selectedCategory.rawValue
        }
    }
    
    private var tipsCurrentPage: Int = 0 {
        didSet {
            tipsPageControl?.currentPage = tipsCurrentPage
        }
    }
    
    private weak var tipsPageControl: UIPageControl?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addWalletView.button.setImage(R.image.ic_title_add(), for: .normal)
        addWalletView.button.addTarget(self, action: #selector(addWallet(_:)), for: .touchUpInside)
        addWalletView.badge = BadgeManager.shared.hasViewed(identifier: .addWallet) ? nil : .unread
        collectionView.register(R.nib.walletSummaryValueCell)
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.walletCell)
        collectionView.register(R.nib.walletSummarySafeIntroductionCell)
        collectionView.register(R.nib.walletTipCell)
        collectionView.register(
            WalletTipPageControlCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.pageControl
        )
        collectionView.register(
            SyncWalletInProgressCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.loading
        )
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .summary:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(152))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(152))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                return section
            case .walletCategories:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(38))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 2, trailing: 15)
                section.orthogonalScrollingBehavior = .continuous
                return section
            case .wallets:
                if let self, let digests = self.digests[self.selectedCategory], !digests.isEmpty {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                    group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: nil)
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
                    return section
                } else if self?.isLoadingSafeWallets ?? false {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3))
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    return section
                } else {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                    group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: nil)
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
                    return section
                }
            case .tips:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(144))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(144))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
                section.orthogonalScrollingBehavior = .groupPaging
                section.visibleItemsInvalidationHandler = { (items, location, environment) in
                    let width = environment.container.contentSize.width
                    let pageOffset = location.x.truncatingRemainder(dividingBy: width)
                    if pageOffset < width / 5 {
                        self?.tipsCurrentPage = Int(location.x / width)
                    }
                }
                return section
            case .tipsPageControl:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let notificationCenter: NotificationCenter = .default
        let reloadDataNotifications = [
            Currency.currentCurrencyDidChangeNotification,
            TokenDAO.tokensDidChangeNotification,
            TokenExtraDAO.tokenVisibilityDidChangeNotification,
            UTXOService.balanceDidUpdateNotification,
            Web3WalletDAO.walletsDidSaveNotification,
            Web3WalletDAO.walletsDidDeleteNotification,
            Web3TokenDAO.tokensDidChangeNotification,
            Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            LoginManager.accountDidChangeNotification,
        ]
        for notification in reloadDataNotifications {
            notificationCenter.addObserver(
                self,
                selector: #selector(reloadData),
                name: notification,
                object: nil
            )
        }
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadTips),
            name: AppGroupUserDefaults.Wallet.didChangeWalletTipNotification,
            object: nil
        )
        
        reloadData()
        reloadTips()
        
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadSafeWallets(_:)),
            name: ReloadSafeWalletsJob.safeWalletsDidUpdateNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadSafeWallets(_:)),
            name: ReloadSafeWalletsJob.safeWalletsFailedToUpdateNotification,
            object: nil
        )
        let reloadSafeWallets = ReloadSafeWalletsJob()
        ConcurrentJobQueue.shared.addJob(job: reloadSafeWallets)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BadgeManager.shared.setHasViewed(identifier: .walletSwitch)
    }
    
    @objc private func addWallet(_ sender: Any) {
        addWalletView.badge = nil
        BadgeManager.shared.setHasViewed(identifier: .addWallet)
        let selector = AddWalletMethodSelectorViewController()
        selector.onSelected = { [weak self] method in
            let introduction = AddWalletIntroductionViewController(action: .addWallet(method))
            self?.navigationController?.pushViewController(introduction, animated: true)
        }
        present(selector, animated: true)
    }
    
    @objc private func reloadTips() {
        let tipsBefore = self.tips
        let tipsAfter = {
            var tips: [WalletTipCell.Content] = []
            if !AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip {
                tips.append(.privacy)
            }
            if !AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip {
                tips.append(.classic)
            }
            if !AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip {
                tips.append(.safe)
            }
            return tips
        }()
        guard tipsBefore != tipsAfter else {
            return
        }
        self.tips = tipsAfter
        if tipsBefore.isEmpty && !tipsAfter.isEmpty {
            collectionView.reloadData()
        } else if !tipsBefore.isEmpty && tipsAfter.isEmpty {
            if collectionView.window == nil {
                collectionView.reloadData()
            } else {
                let sections = IndexSet(arrayLiteral: Section.tips.rawValue, Section.tipsPageControl.rawValue)
                collectionView.deleteSections(sections)
            }
        } else {
            let deletedItem: Int
            if let index = tipsBefore.firstIndex(of: .privacy), !tipsAfter.contains(.privacy) {
                deletedItem = index
            } else if let index = tipsBefore.firstIndex(of: .classic), !tipsAfter.contains(.classic) {
                deletedItem = index
            } else {
                // Adding items, must be diagnose
                collectionView.reloadData()
                return
            }
            let indexPath = IndexPath(item: deletedItem, section: Section.tips.rawValue)
            collectionView.deleteItems(at: [indexPath])
            tipsPageControl?.numberOfPages = tips.count
            tipsCurrentPage = 0
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async {
            let privacyWalletDigest = TokenDAO.shared.walletDigest()
            let commonWalletDigests = Web3WalletDAO.shared.walletDigests()
            let safeWalletDigests = SafeWalletDAO.shared.walletDigests()
            let walletDigests = [privacyWalletDigest] + commonWalletDigests + safeWalletDigests
            let summary = WalletSummary(walletDigests: walletDigests)
            let categorizedDigests = WalletDisplayCategory.categorize(digests: walletDigests)
                .filter { category, wallets in
                    category == .safe || !wallets.isEmpty
                }
            var secretAvailableWalletIDs: Set<String> = Set(
                AppGroupKeychain.allImportedMnemonics().keys
            )
            secretAvailableWalletIDs.formUnion(
                AppGroupKeychain.allImportedPrivateKey().keys
            )
            DispatchQueue.main.async {
                self.summary = summary
                self.digests = categorizedDigests
                self.secretAvailableWalletIDs = secretAvailableWalletIDs
                self.unexpiredPlan = LoginManager.shared.account?.membership?.unexpiredPlan
                self.collectionView.reloadData()
                if let item = categorizedDigests.keys.firstIndex(of: self.selectedCategory) {
                    let indexPath = IndexPath(item: item, section: Section.walletCategories.rawValue)
                    self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                }
            }
        }
    }
    
    @objc private func reloadSafeWallets(_ notification: Notification) {
        self.isLoadingSafeWallets = false
        self.reloadData()
    }
    
}

extension WalletSummaryViewController: WalletTipCell.Delegate {
    
    func walletTipCellWantsToClose(_ cell: WalletTipCell) {
        guard let content = cell.content else {
            return
        }
        switch content {
        case .privacy:
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip = true
        case .classic:
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip = true
        case .safe:
            AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip = true
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sections: [Section] = [.summary, .walletCategories, .wallets]
        if !tips.isEmpty {
            sections.append(.tips)
            sections.append(.tipsPageControl)
        }
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .summary:
            return 1
        case .walletCategories:
            return digests.count
        case .wallets:
            let count = digests[selectedCategory]?.count ?? 0
            if selectedCategory == .safe && count == 0 {
                return 1
            } else {
                return count
            }
        case .tips:
            return tips.count
        case .tipsPageControl:
            return 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .summary:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_value, for: indexPath)!
            if let summary {
                cell.load(summary: summary)
            }
            cell.delegate = self
            return cell
        case .walletCategories:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let category = digests.keys[indexPath.item]
            cell.label.text = category.localizedName
            switch category {
            case .safe:
                cell.badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .safeVault)
            default:
                cell.badgeView.isHidden = true
            }
            return cell
        case .wallets:
            if let digests = digests[selectedCategory], !digests.isEmpty {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
                let digest = digests[indexPath.item]
                let hasSecret: Bool
                switch digest.wallet {
                case .privacy:
                    cell.accessory = .disclosure
                    hasSecret = false
                case .common(let wallet):
                    cell.accessory = .disclosure
                    hasSecret = secretAvailableWalletIDs.contains(wallet.walletID)
                case .safe:
                    cell.accessory = .external
                    hasSecret = false
                }
                cell.load(digest: digest, hasSecret: hasSecret)
                return cell
            } else {
                if isLoadingSafeWallets {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.loading, for: indexPath)
                    return cell
                } else {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_safe_introduction, for: indexPath)!
                    if unexpiredPlan == nil {
                        cell.load(content: .upgradePlan)
                    } else {
                        cell.load(content: .createSafe)
                    }
                    cell.actionView.delegate = self
                    return cell
                }
            }
        case .tips:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_tip_cell, for: indexPath)!
            cell.content = tips[indexPath.item]
            cell.delegate = self
            return cell
        case .tipsPageControl:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.pageControl, for: indexPath) as! WalletTipPageControlCell
            cell.pageControl.numberOfPages = tips.count
            cell.pageControl.currentPage = tipsCurrentPage
            self.tipsPageControl = cell.pageControl
            return cell
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .summary, .tips, .tipsPageControl:
            false
        case .walletCategories, .wallets:
            true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .summary, .tips, .tipsPageControl:
            break
        case .walletCategories:
            collectionView.indexPathsForSelectedItems?.forEach { selectedIndexPath in
                if selectedIndexPath.section == indexPath.section,
                   selectedIndexPath.item != indexPath.item
                {
                    collectionView.deselectItem(at: selectedIndexPath, animated: false)
                }
            }
            selectedCategory = digests.keys[indexPath.item]
            switch selectedCategory {
            case .safe:
                BadgeManager.shared.setHasViewed(identifier: .safeVault)
                if let cell = collectionView.cellForItem(at: indexPath) as? ExploreSegmentCell {
                    cell.badgeView.isHidden = true
                }
            default:
                break
            }
            UIView.performWithoutAnimation {
                let sections = IndexSet(integer: Section.wallets.rawValue)
                collectionView.reloadSections(sections)
            }
        case .wallets:
            collectionView.deselectItem(at: indexPath, animated: true)
            guard let wallet = digests[selectedCategory]?[indexPath.item].wallet else {
                return
            }
            switch wallet {
            case .privacy, .common:
                let container = parent as? WalletContainerViewController
                container?.switchToWallet(wallet)
            case .safe(let wallet):
                guard let url = URL(string: wallet.uri) else {
                    return
                }
                let container = UIApplication.homeContainerViewController
                let context = MixinWebViewController.Context(
                    conversationId: "",
                    initialUrl: url,
                    saveAsRecentSearch: false
                )
                container?.presentWebViewController(context: context)
            }
        }
    }
    
}

extension WalletSummaryViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        if unexpiredPlan == nil {
            if index == 0 {
                let buy = MembershipPlansViewController(selectedPlan: nil)
                present(buy, animated: true)
            } else {
                let safari = SFSafariViewController(url: .learnAboutSafe)
                present(safari, animated: true)
            }
        } else {
            let safari = SFSafariViewController(url: .createSafeGuide)
            present(safari, animated: true)
        }
    }
    
}

extension WalletSummaryViewController: WalletSummaryValueCell.Delegate {
    
    func walletSummaryValueCellRequestTip(_ cell: WalletSummaryValueCell) {
        let tipView = R.nib.overlayTipView(withOwner: nil)!
        view.addSubview(tipView)
        tipView.snp.makeEdgesEqualToSuperview()
        tipView.label.text = R.string.localizable.wallet_summary_tip()
        view.layoutIfNeeded()
        let center = cell.convert(cell.infoButton.center, to: tipView)
        tipView.placeTip(at: center)
    }
    
}

extension WalletSummaryViewController {
    
    private final class SyncWalletInProgressCell: UICollectionViewCell {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        private func loadSubviews() {
            let indicator = ActivityIndicatorView()
            contentView.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview().multipliedBy(2)
            }
            indicator.tintColor = R.color.icon_tint_tertiary()
            indicator.startAnimating()
        }
        
    }
    
}
