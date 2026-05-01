import UIKit
import SafariServices
import MixinServices

final class WalletSummaryViewController: UIViewController {
    
    @IBOutlet weak var addWalletView: BadgeBarButtonView!
    @IBOutlet weak var categorySelectorCollectionView: UICollectionView!
    @IBOutlet weak var categorySelectorLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var categorySelectorHeightConstraint: NSLayoutConstraint!
    
    private var categorySelectorSizeObserver: NSKeyValueObservation?
    private var categorySelectorController: CategorySelectorController!
    private var sections: [Section] = []
    private var pages: [WalletDisplayCategory: CategoryPage] = [:]
    private var tips: [WalletTipCell.Content] = []
    private var secretAvailableWalletIDs: Set<String> = []
    private var unexpiredPlan: User.Membership.Plan?
    private var isLoadingSafeWallets = true
    
    private var tipsCurrentPage: Int = 0 {
        didSet {
            tipsPageControl?.currentPage = tipsCurrentPage
        }
    }
    
    private weak var collectionView: UICollectionView!
    private weak var tipsPageControl: UIPageControl?
    
    init() {
        let nib = R.nib.walletSummaryView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addWalletView.button.setImage(R.image.ic_title_add(), for: .normal)
        addWalletView.button.addTarget(self, action: #selector(addWallet(_:)), for: .touchUpInside)
        addWalletView.badge = BadgeManager.shared.hasViewed(identifier: .addWallet) ? nil : .unread
        
        categorySelectorLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        categorySelectorController = CategorySelectorController(
            collectionView: categorySelectorCollectionView
        )
        categorySelectorCollectionView.register(R.nib.exploreSegmentCell)
        categorySelectorCollectionView.dataSource = categorySelectorController
        categorySelectorCollectionView.delegate = categorySelectorController
        categorySelectorController.delegate = self
        categorySelectorSizeObserver = categorySelectorCollectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.categorySelectorHeightConstraint.constant = newValue.height
            self.view.layoutIfNeeded()
        }
        
        let layout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch self?.sections[sectionIndex] {
            case .loading:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(0.3))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            case .none, .summary:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(152))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20)
                return section
            case .wallets:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            case .introduction:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            case .tips:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(144))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
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
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(categorySelectorCollectionView.snp.bottom)
        }
        self.collectionView = collectionView
        collectionView.register(R.nib.walletSummaryValueCell)
        collectionView.register(R.nib.walletCell)
        collectionView.register(R.nib.walletSummaryIntroductionCell)
        collectionView.register(R.nib.walletTipCell)
        collectionView.register(
            WalletTipPageControlCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.pageControl
        )
        collectionView.register(
            SyncWalletInProgressCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.loading
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let category = WalletDisplayCategory(
            rawValue: AppGroupUserDefaults.Wallet.lastSelectedCategory
        ) ?? .all
        categorySelectorController.select(category: category)
        
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
        
        var tips, tipsPageControl: Int?
        for (index, section) in sections.enumerated() {
            switch section {
            case .tips:
                tips = index
            case .tipsPageControl:
                tipsPageControl = index
            default:
                break
            }
        }
        if tipsBefore.isEmpty && !tipsAfter.isEmpty {
            sections.append(contentsOf: [.tips, .tipsPageControl])
            collectionView.reloadData()
        } else if !tipsBefore.isEmpty && tipsAfter.isEmpty {
            if let tips, let tipsPageControl {
                sections.remove(at: tipsPageControl)
                sections.remove(at: tips)
                if collectionView.window == nil {
                    collectionView.reloadData()
                } else {
                    let sections = IndexSet(arrayLiteral: tips, tipsPageControl)
                    collectionView.deleteSections(sections)
                }
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
            if let section = tips {
                self.tipsPageControl?.numberOfPages = tipsAfter.count
                let indexPath = IndexPath(item: deletedItem, section: section)
                collectionView.deleteItems(at: [indexPath])
            }
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async {
            let privacyWalletDigest = TokenDAO.shared.walletDigest()
            let commonWalletDigests = Web3WalletDAO.shared.walletDigests()
            let safeWalletDigests = SafeWalletDAO.shared.walletDigests()
            let pages: [WalletDisplayCategory: CategoryPage] = WalletDisplayCategory.categorize(
                digests: [privacyWalletDigest] + commonWalletDigests + safeWalletDigests
            ).reduce(into: [:]) { (results, element) in
                let (category, allDigests) = element
                guard !allDigests.isEmpty else {
                    return
                }
                let summarizingDigests = switch category {
                case .all, .created, .imported, .watching:
                    allDigests
                case .safe:
                    allDigests.filter { digest in
                        switch digest.wallet {
                        case .privacy, .common:
                            false
                        case .safe(let wallet):
                            wallet.role == .known(.owner)
                        }
                    }
                }
                let summary = WalletSummary(digests: summarizingDigests)
                results[category] = CategoryPage(summary: summary, digests: allDigests)
            }
            var secretAvailableWalletIDs: Set<String> = Set(
                AppGroupKeychain.allImportedMnemonics().keys
            )
            secretAvailableWalletIDs.formUnion(
                AppGroupKeychain.allImportedPrivateKey().keys
            )
            DispatchQueue.main.async {
                self.pages = pages
                self.secretAvailableWalletIDs = secretAvailableWalletIDs
                self.unexpiredPlan = LoginManager.shared.account?.membership?.unexpiredPlan
                if let category = self.categorySelectorController.selectedCategory {
                    self.updateSections(category: category)
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    @objc private func reloadSafeWallets(_ notification: Notification) {
        self.isLoadingSafeWallets = false
        self.reloadData()
    }
    
    private func updateSections(category: WalletDisplayCategory) {
        var sections: [Section] = []
        switch category {
        case .safe where isLoadingSafeWallets:
            sections.append(.loading)
        default:
            if let page = pages[category] {
                sections.append(contentsOf: [
                    .summary(summary: page.summary, tip: category.summaryTip),
                    .wallets(page.digests)
                ])
            } else {
                sections.append(.introduction(category))
            }
        }
        if !tips.isEmpty {
            sections.append(contentsOf: [.tips, .tipsPageControl])
        }
        self.sections = sections
    }
    
}

extension WalletSummaryViewController: WalletTipCell.Delegate {
    
    func walletTipCell(_ cell: WalletTipCell, requestToLearnMore url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
}

extension WalletSummaryViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .loading:
            1
        case .summary:
            1
        case .wallets(let digests):
            digests.count
        case .introduction:
            1
        case .tips:
            tips.count
        case .tipsPageControl:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .loading:
            return collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.loading, for: indexPath)
        case let .summary(summary, tip):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_value, for: indexPath)!
            cell.load(summary: summary)
            cell.infoButton.isHidden = tip == nil
            cell.presentTip = { [weak self] (cell) in
                guard let self else {
                    return
                }
                let tipView = R.nib.overlayTipView(withOwner: nil)!
                self.view.addSubview(tipView)
                tipView.snp.makeEdgesEqualToSuperview()
                tipView.label.text = tip
                self.view.layoutIfNeeded()
                let center = cell.convert(cell.infoButton.center, to: tipView)
                tipView.placeTip(at: center)
            }
            return cell
        case .wallets(let digests):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            assert(!digests.isEmpty)
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
        case .introduction(let category):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_introduction, for: indexPath)!
            switch category {
            case .all, .created:
                assertionFailure("No intro for default wallets")
                fallthrough
            case .imported:
                cell.content = .imported
            case .watching:
                cell.content = .watch
            case .safe:
                if unexpiredPlan == nil {
                    cell.content = .upgradePlan
                } else {
                    cell.content = .createSafe
                }
            }
            cell.delegate = self
            return cell
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
        switch sections[indexPath.section] {
        case .wallets:
            true
        default:
            false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .loading, .summary, .introduction, .tips, .tipsPageControl:
            break
        case .wallets(let digests):
            collectionView.deselectItem(at: indexPath, animated: true)
            let wallet = digests[indexPath.item].wallet
            switch wallet {
            case .privacy, .common:
                let container = parent as? WalletContainerViewController
                container?.switchToWallet(wallet)
            case .safe(let wallet):
                guard let url = URL(string: wallet.uri) else {
                    return
                }
                let isOpened = UrlWindow.checkUrl(url: url)
                if !isOpened, let container = UIApplication.homeContainerViewController {
                    let context = MixinWebContext(
                        conversationId: "",
                        initialUrl: url,
                        saveAsRecentSearch: false
                    )
                    container.presentWebViewController(context: context)
                }
            }
        }
    }
    
}

extension WalletSummaryViewController: WalletSummaryIntroductionCell.Delegate {
    
    func walletSummaryIntroductionCell(_ cell: WalletSummaryIntroductionCell, didSelectActionAtIndex index: Int) {
        switch cell.content {
        case .imported:
            if index == 0 {
                addWallet(cell)
            } else {
                let safari = SFSafariViewController(url: .importWallet)
                present(safari, animated: true)
            }
        case .watch:
            if index == 0 {
                addWallet(cell)
            } else {
                let safari = SFSafariViewController(url: .watchWallet)
                present(safari, animated: true)
            }
        case .upgradePlan:
            if index == 0 {
                let buy = MembershipPlansViewController(selectedPlan: nil)
                present(buy, animated: true)
            } else {
                let safari = SFSafariViewController(url: .learnAboutSafe)
                present(safari, animated: true)
            }
        case .createSafe:
            if unexpiredPlan == nil {
            } else {
                let safari = SFSafariViewController(url: .createSafeGuide)
                present(safari, animated: true)
            }
        case .none:
            break
        }
    }
    
}

extension WalletSummaryViewController: WalletSummaryViewController.CategorySelectorControllerDelegate {
    
    func categorySelectorController(_ controller: CategorySelectorController, didSelectCategory category: WalletDisplayCategory) {
        AppGroupUserDefaults.Wallet.lastSelectedCategory = category.rawValue
        updateSections(category: category)
        collectionView.reloadData()
    }
    
}

extension WalletSummaryViewController {
    
    protocol CategorySelectorControllerDelegate: AnyObject {
        func categorySelectorController(
            _ controller: CategorySelectorController,
            didSelectCategory category: WalletDisplayCategory
        )
    }
    
    final class CategorySelectorController: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        
        weak var delegate: CategorySelectorControllerDelegate?
        
        var selectedCategory: WalletDisplayCategory? {
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                categories[indexPath.item]
            } else {
                nil
            }
        }
        
        private let collectionView: UICollectionView
        private let categories: [WalletDisplayCategory] = [
            .all, .created, .imported, .watching, .safe
        ]
        
        init(collectionView: UICollectionView) {
            self.collectionView = collectionView
            super.init()
        }
        
        func select(category: WalletDisplayCategory) {
            guard let item = categories.firstIndex(of: category) else {
                return
            }
            let indexPath = IndexPath(item: item, section: 0)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            categories.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            let category = categories[indexPath.item]
            cell.label.text = category.localizedName
            switch category {
            case .safe:
                cell.badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .safeVault)
            default:
                cell.badgeView.isHidden = true
            }
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
            false
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let category = categories[indexPath.item]
            switch category {
            case .safe:
                BadgeManager.shared.setHasViewed(identifier: .safeVault)
                if let cell = collectionView.cellForItem(at: indexPath) as? ExploreSegmentCell {
                    cell.badgeView.isHidden = true
                }
            default:
                break
            }
            delegate?.categorySelectorController(self, didSelectCategory: category)
        }
        
    }
    
}

extension WalletSummaryViewController {
    
    private enum Section {
        case loading
        case summary(summary: WalletSummary, tip: String?)
        case wallets([WalletDigest])
        case introduction(WalletDisplayCategory)
        case tips
        case tipsPageControl
    }
    
    private struct CategoryPage {
        let summary: WalletSummary
        let digests: [WalletDigest]
    }
    
    private enum ReuseIdentifier {
        static let pageControl = "p"
        static let loading = "l"
    }
    
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
