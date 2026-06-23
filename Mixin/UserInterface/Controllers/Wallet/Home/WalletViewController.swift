import UIKit
import SafariServices
import OrderedCollections
import MixinServices

class WalletViewController: UIViewController, AssetChangeAccountRecoveryChecking {
    
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var titleInfoStackView: UIStackView!
    @IBOutlet weak var walletSwitchImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    let itemsCount = 3
    let perpsTopMoversCount = 4
    
    var overview: WalletOverview?
    var overviewAction: WalletOverview.Action?
    var overviewTray: WalletOverview.Tray?
    
    var tokensValue: String?
    var hasMoreTokens = false
    
    var perpsValue: PerpetualPositionValue?
    var perpsPositions: OrderedDictionary<String, PerpetualPositionViewModel> = [:]
    var perpsPositionsCount = 0
    var hasMorePerpsPositions = false
    
    var hasMoreTransactions = false
    
    var perpsTopMovers: OrderedDictionary<String, PerpetualMarketViewModel> = [:]
    
    var walletActionHandler: (any WalletActionHandler)?
    
    private(set) weak var collectionView: UICollectionView!
    
    private(set) var isViewAppearing = false
    private(set) var dataSource: DiffableDataSource!
    private(set) var remoteBanners: [AppBanner] = []
    
    private weak var bannersPageControl: UIPageControl?
    
    private var allowsReloadingRemoteBanners = true
    
    private var bannersCurrentPage: Int = 0 {
        didSet {
            bannersPageControl?.currentPage = bannersCurrentPage
        }
    }
    
    init() {
        let nib = R.nib.walletView
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
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, environment in
                guard let section = self?.dataSource?.sectionIdentifier(for: sectionIndex) else {
                    return nil
                }
                
                func singleItem(estimatedHeight: CGFloat) -> NSCollectionLayoutSection {
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(estimatedHeight))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    return section
                }
                
                func listSection(
                    showFooter: Bool,
                    trailingSwipeActionsConfigurationProvider: UICollectionLayoutListConfiguration.SwipeActionsConfigurationProvider?
                ) -> NSCollectionLayoutSection {
                    let contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    
                    var config = UICollectionLayoutListConfiguration(appearance: .plain)
                    config.showsSeparators = false
                    config.backgroundColor = .clear
                    config.trailingSwipeActionsConfigurationProvider = trailingSwipeActionsConfigurationProvider
                    config.headerMode = .supplementary
                    config.headerTopPadding = 0
                    
                    let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
                    section.interGroupSpacing = 20
                    
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(57)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                    header.contentInsets = contentInsets
                    section.boundarySupplementaryItems = [header]
                    
                    if showFooter {
                        config.footerMode = .supplementary
                        let footer = NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
                            elementKind: UICollectionView.elementKindSectionFooter,
                            alignment: .bottom
                        )
                        footer.contentInsets = contentInsets
                        section.boundarySupplementaryItems.append(footer)
                        section.contentInsets = contentInsets
                    } else {
                        config.footerMode = .none
                        section.contentInsets = NSDirectionalEdgeInsets(
                            top: contentInsets.top,
                            leading: contentInsets.leading,
                            bottom: contentInsets.bottom + 20,
                            trailing: contentInsets.trailing
                        )
                    }
                    
                    section.decorationItems = {
                        let background: NSCollectionLayoutDecorationItem = .background(
                            elementKind: TradeSectionBackgroundView.elementKind
                        )
                        background.contentInsets = contentInsets
                        return [background]
                    }()
                    return section
                }
                
                switch section {
                case .overview:
                    let section = singleItem(estimatedHeight: 216)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    if case .importSecret = self?.overviewAction {
                        section.boundarySupplementaryItems = [
                            NSCollectionLayoutBoundarySupplementaryItem(
                                layoutSize: NSCollectionLayoutSize(
                                    widthDimension: .fractionalWidth(1),
                                    heightDimension: .estimated(60)
                                ),
                                elementKind: UICollectionView.elementKindSectionFooter,
                                alignment: .bottom
                            ),
                        ]
                    }
                    return section
                case .emptyWalletInstruction:
                    let section = singleItem(estimatedHeight: 290)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .banners:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(110))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.orthogonalScrollingBehavior = .groupPaging
                    if #available(iOS 17.0, *) {
                        section.orthogonalScrollingProperties.bounce = .always
                    }
                    let bannersCount = self?.dataSource.snapshot().numberOfItems(inSection: .banners) ?? 0
                    if bannersCount > 1 {
                        section.visibleItemsInvalidationHandler = { (items, location, environment) in
                            let width = environment.container.contentSize.width
                            let pageOffset = location.x.truncatingRemainder(dividingBy: width)
                            if pageOffset < width / 5 {
                                self?.bannersCurrentPage = Int(location.x / width)
                            }
                        }
                        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(16))
                        let footer = NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: footerSize,
                            elementKind: UICollectionView.elementKindSectionFooter,
                            alignment: .bottom
                        )
                        section.boundarySupplementaryItems = [footer]
                    } else {
                        section.visibleItemsInvalidationHandler = nil
                    }
                    return section
                case .perpsPositions:
                    return listSection(
                        showFooter: self?.hasMorePerpsPositions ?? false,
                        trailingSwipeActionsConfigurationProvider: nil
                    )
                case .tokens:
                    return listSection(
                        showFooter: self?.hasMoreTokens ?? false
                    ) { [weak self] indexPath in
                        self?.hideTokenAction(indexPath: indexPath)
                    }
                case .transactions:
                    return listSection(
                        showFooter: self?.hasMoreTransactions ?? false,
                        trailingSwipeActionsConfigurationProvider: nil
                    )
                case .perpsTopMovers:
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(76),
                        heightDimension: .estimated(85)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(85)
                        ),
                        subitem: item,
                        count: 4
                    )
                    group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = 16
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .absolute(57)
                            ),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        ),
                    ]
                    let background: NSCollectionLayoutDecorationItem = .background(
                        elementKind: TradeSectionBackgroundView.elementKind
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    section.decorationItems = [background]
                    return section
                case .referral:
                    let section = singleItem(estimatedHeight: 244)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .support:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
                    section.interGroupSpacing = 20
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(57)),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        ),
                    ]
                    section.decorationItems = {
                        let background: NSCollectionLayoutDecorationItem = .background(
                            elementKind: TradeSectionBackgroundView.elementKind
                        )
                        background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                        return [background]
                    }()
                    return section
                case .benefit:
                    let section = singleItem(estimatedHeight: 239)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 26, leading: 28, bottom: 0, trailing: 28)
                    return section
                }
            },
            configuration: config
        )
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        let emptyWalletInstructionRegistration = UICollectionView.CellRegistration<EmptyWalletInstructionCell, Void>(
            cellNib: UINib(resource: R.nib.emptyWalletInstructionCell)
        ) { [weak self] cell, indexPath, _ in
            cell.delegate = self
        }
        let bannerRegistration = UICollectionView.CellRegistration<WalletBannerCell, WalletBanner>(
            cellNib: UINib(resource: R.nib.walletBannerCell)
        ) { [weak self] cell, indexPath, banner in
            cell.banner = banner
            cell.delegate = self
        }
        let bannerPageControlRegistration = UICollectionView.SupplementaryRegistration<WalletBannerPageControlFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footerView, elementKind, indexPath in
            guard let self else {
                return
            }
            let bannersCount = self.dataSource.snapshot().numberOfItems(inSection: .banners)
            footerView.configure(with: bannersCount, currentPage: 0)
            self.bannersPageControl = footerView.pageControl
        }
        let supportRegistration = UICollectionView.CellRegistration<WalletSupportCell, WalletSupport>(
            cellNib: UINib(resource: R.nib.walletSupportCell)
        ) { cell, indexPath, content in
            cell.content = content
        }
        let benefitRegistration = UICollectionView.CellRegistration<WalletBenefitCell, WalletBenefit>(
            cellNib: UINib(resource: R.nib.walletBenefitCell)
        ) { cell, indexPath, benefit in
            cell.benefit = benefit
        }
        let referralRegistration = UICollectionView.CellRegistration<WalletReferralCell, Void>(
            cellNib: UINib(resource: R.nib.walletReferralCell)
        ) { [weak self] cell, indexPath, _ in
            cell.delegate = self
        }
        let dataSource = DiffableDataSource(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            switch item {
            case .overview:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_overview, for: indexPath)!
                if let self {
                    cell.load(overview: self.overview)
                    cell.load(action: self.overviewAction)
                    cell.load(tray: self.overviewTray)
                    cell.delegate = self.walletActionHandler
                }
                return cell
            case .emptyWalletInstruction:
                return collectionView.dequeueConfiguredReusableCell(using: emptyWalletInstructionRegistration, for: indexPath, item: ())
            case let .banner(banner):
                return collectionView.dequeueConfiguredReusableCell(using: bannerRegistration, for: indexPath, item: banner)
            case let .perpsPosition(positionID):
                if let viewModel = self?.perpsPositions[positionID] {
                    switch viewModel.state {
                    case .opening:
                        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_activity, for: indexPath)!
                        cell.load(viewModel: viewModel)
                        return cell
                    default:
                        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                        cell.load(viewModel: viewModel)
                        return cell
                    }
                } else {
                    assertionFailure()
                    return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                }
            case let .token(assetID):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.token, for: indexPath)!
                self?.configure(tokenCell: cell, withTokenOf: assetID)
                return cell
            case let .transaction(id):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.transaction, for: indexPath)!
                self?.configure(transactionCell: cell, withTransactionOf: id)
                cell.delegate = self as? TransactionCell.Delegate
                return cell
            case let .perpsTopMover(marketID):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_top_mover, for: indexPath)!
                if let viewModel = self?.perpsTopMovers[marketID] {
                    cell.load(viewModel: viewModel)
                }
                return cell
            case .referral:
                return collectionView.dequeueConfiguredReusableCell(using: referralRegistration, for: indexPath, item: ())
            case let .support(content):
                return collectionView.dequeueConfiguredReusableCell(using: supportRegistration, for: indexPath, item: content)
            case let .benefit(benefit):
                return collectionView.dequeueConfiguredReusableCell(using: benefitRegistration, for: indexPath, item: benefit)
            }
        }
        dataSource.supplementaryViewProvider = { [unowned dataSource, weak self] collectionView, elementKind, indexPath in
            guard let section = dataSource.sectionIdentifier(for: indexPath.section) else {
                return nil
            }
            switch section {
            case .overview:
                switch self?.overviewAction {
                case .importSecret(let action):
                    let footer = collectionView.dequeueReusableSupplementaryView(
                        ofKind: UICollectionView.elementKindSectionFooter,
                        withReuseIdentifier: WalletOverviewFooterView.reuseIdentifier,
                        for: indexPath
                    ) as! WalletOverviewFooterView
                    footer.action = action
                    return footer
                case .general, .none:
                    return nil
                }
            case .banners:
                return collectionView.dequeueConfiguredReusableSupplementary(using: bannerPageControlRegistration, for: indexPath)
            case .perpsPositions:
                switch elementKind {
                case UICollectionView.elementKindSectionHeader:
                    let header = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
                    header.titleLabel.text = R.string.localizable.positions_count(self?.perpsPositionsCount ?? 0)
                    header.subtitleLabel.text = self?.perpsValue?.value
                    header.disclosureImageView.isHidden = false
                    header.onShowAll = { _ in
                        self?.viewPerps()
                    }
                    return header
                case UICollectionView.elementKindSectionFooter:
                    let footer = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier, for: indexPath) as! TradeViewAllFooterView
                    footer.onViewAll = { _ in
                        self?.viewPerps()
                    }
                    return footer
                default:
                    return nil
                }
            case .tokens:
                switch elementKind {
                case UICollectionView.elementKindSectionHeader:
                    let header = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
                    header.titleLabel.text = R.string.localizable.wallet_home_tokens()
                    header.subtitleLabel.text = self?.tokensValue
                    header.disclosureImageView.isHidden = false
                    header.onShowAll = { _ in
                        self?.viewAllTokens()
                    }
                    return header
                case UICollectionView.elementKindSectionFooter:
                    let footer = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier, for: indexPath) as! TradeViewAllFooterView
                    footer.onViewAll = { _ in
                        self?.viewAllTokens()
                    }
                    return footer
                default:
                    return nil
                }
            case .transactions:
                switch elementKind {
                case UICollectionView.elementKindSectionHeader:
                    let header = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
                    header.titleLabel.text = R.string.localizable.transactions()
                    header.subtitleLabel.text = nil
                    header.disclosureImageView.isHidden = false
                    header.onShowAll = { _ in
                        self?.viewAllTransactions()
                    }
                    return header
                case UICollectionView.elementKindSectionFooter:
                    let footer = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier, for: indexPath) as! TradeViewAllFooterView
                    footer.onViewAll = { _ in
                        self?.viewAllTransactions()
                    }
                    return footer
                default:
                    return nil
                }
            case .perpsTopMovers:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
                header.titleLabel.text = R.string.localizable.perpetual()
                header.subtitleLabel.text = nil
                header.disclosureImageView.isHidden = false
                header.onShowAll = { _ in
                    self?.viewPerps()
                }
                return header
            case .support:
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
                header.titleLabel.text = R.string.localizable.wallet_home_support()
                header.subtitleLabel.text = nil
                header.disclosureImageView.isHidden = true
                header.onShowAll = nil
                return header
            default:
                return nil
            }
        }
        collectionView.register(R.nib.walletOverviewCell)
        collectionView.register(R.nib.perpetualActivityCell)
        collectionView.register(R.nib.perpetualMarketCell)
        collectionView.register(R.nib.tokenCell)
        collectionView.register(R.nib.transactionCell)
        collectionView.register(R.nib.perpetualTopMoverCell)
        collectionView.register(
            R.nib.tradeSectionHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            WalletOverviewFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: WalletOverviewFooterView.reuseIdentifier
        )
        collectionView.register(
            TradeViewAllFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier
        )
        collectionView.dataSource = dataSource
        self.collectionView = collectionView
        self.dataSource = dataSource
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isViewAppearing = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewAppearing = false
        allowsReloadingRemoteBanners = true
    }
    
    @IBAction func switchFromWallets(_ sender: Any) {
        if let parent = parent as? WalletContainerViewController {
            parent.switchToWalletSummary(animated: true)
        }
        BadgeManager.shared.setHasViewed(identifier: .walletSwitch)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        
    }
    
    @IBAction func scanQRCode() {
        UIApplication.homeNavigationController?.pushQRCodeScannerViewController()
    }
    
    @IBAction func moreAction(_ sender: Any) {
        
    }
    
    func addIconIntoTitleView(image: UIImage?) {
        let iconView = UIImageView(image: image)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        iconView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleInfoStackView.addArrangedSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }
    }
    
    func request(support: WalletSupport) {
        switch support {
        case .contactUs:
            if let conversation = ConversationViewController.teamMixin() {
                navigationController?.pushViewController(withBackRoot: conversation)
            }
        case .helpCenter:
            let safari = SFSafariViewController(url: .support)
            present(safari, animated: true)
        }
    }
    
    func configure(tokenCell: TokenCell, withTokenOf assetID: String) {
        
    }
    
    func configure(transactionCell: TransactionCell, withTransactionOf id: String) {
        
    }
    
    func hideTokenAction(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        nil
    }
    
    func viewAllTokens() {
        
    }
    
    func viewAllTransactions() {
        
    }
    
    func viewPerps() {
        
    }
    
}

extension WalletViewController {
    
    enum Section {
        case overview
        case emptyWalletInstruction
        case banners
        case perpsPositions
        case tokens
        case transactions
        case perpsTopMovers
        case referral
        case support
        case benefit
    }
    
    enum Item: Hashable {
        case overview
        case emptyWalletInstruction
        case banner(WalletBanner)
        case perpsPosition(positionID: String)
        case token(assetID: String)
        case transaction(id: String)
        case perpsTopMover(marketID: String)
        case referral
        case support(WalletSupport)
        case benefit(WalletBenefit)
    }
    
    typealias DiffableDataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<Section, Item>
    
    func insertBannersReferralSection(into snapshot: inout DataSourceSnapshot) {
        var banners: [WalletBanner] = remoteBanners.map({ .remote($0) })
        if !BadgeManager.shared.hasViewed(identifier: .addWalletBanner) {
            banners.append(.embedded(.addWallet))
        }
        if !banners.isEmpty, let firstSection = snapshot.sectionIdentifiers.first {
            snapshot.insertSections([.banners], afterSection: firstSection)
            snapshot.appendItems(banners.map({ Item.banner($0) }), toSection: .banners)
        }
        if !BadgeManager.shared.hasViewed(identifier: .walletHomeReferral) {
            snapshot.insertSections([.referral], beforeSection: .support)
            snapshot.appendItems([.referral], toSection: .referral)
        }
    }
    
    // nil for all chains
    func reloadRemoteBannersIfAllowed(chainIDs: Set<String>?) {
        guard allowsReloadingRemoteBanners && isViewAppearing else {
            return
        }
        allowsReloadingRemoteBanners = false
        RewardAPI.appBanners(chainIDs: chainIDs) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let banners):
                if banners.isEmpty {
                    AppGroupUserDefaults.Wallet.closedBannerIDs = []
                }
                let closedBannerIDs = Set(AppGroupUserDefaults.Wallet.closedBannerIDs)
                let displayBanners = banners.filter { banner in
                    !closedBannerIDs.contains(banner.bannerID)
                }
                self.remoteBanners = displayBanners
                let bannerItems = displayBanners.map { banner in
                    Item.banner(.remote(banner))
                }
                var snapshot = self.dataSource.snapshot()
                if snapshot.sectionIdentifiers.contains(.banners) {
                    snapshot.deleteItems(
                        snapshot.itemIdentifiers(inSection: .banners).filter { item in
                            switch item {
                            case .banner(.remote):
                                true
                            default:
                                false
                            }
                        }
                    )
                    if !bannerItems.isEmpty {
                        if let firstItem = snapshot.itemIdentifiers(inSection: .banners).first {
                            snapshot.insertItems(bannerItems, beforeItem: firstItem)
                        } else {
                            snapshot.appendItems(bannerItems, toSection: .banners)
                        }
                    }
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                } else if !bannerItems.isEmpty {
                    if let firstSection = snapshot.sectionIdentifiers.first {
                        snapshot.insertSections([.banners], afterSection: firstSection)
                    } else {
                        snapshot.appendSections([.banners])
                    }
                    snapshot.appendItems(bannerItems, toSection: .banners)
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            case .failure(let error):
                Logger.general.debug(category: "Wallet", message: "\(error)")
            }
        }
    }
    
}

extension WalletViewController: EmptyWalletInstructionCell.Delegate {
    
    func emptyWalletInstructionCellRequestToBuy(_ cell: EmptyWalletInstructionCell) {
        walletActionHandler?.buy()
    }
    
    func emptyWalletInstructionCellRequestToReceive(_ cell: EmptyWalletInstructionCell) {
        walletActionHandler?.receive()
    }
    
}

extension WalletViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .hide
    }
    
}

extension WalletViewController: WalletBannerCell.Delegate {
    
    func walletBannerCell(_ cell: WalletBannerCell, requestPerformAction banner: WalletBanner, index: Int) {
        switch banner {
        case .embedded(let banner):
            switch banner {
            case .addWallet:
                BadgeManager.shared.setHasViewed(identifier: .addWalletAction)
                let selector = AddWalletMethodSelectorViewController()
                selector.onSelected = { [weak self] method in
                    let introduction = AddWalletIntroductionViewController(action: .addWallet(method))
                    self?.navigationController?.pushViewController(introduction, animated: true)
                }
                present(selector, animated: true)
            }
        case .remote(let banner):
            if let action = banner.actions?[index].action,
               let url = URL(string: action)
            {
                _ = UrlWindow.checkUrl(url: url)
                if !banner.trackingKey.isEmpty {
                    reporter.report(
                        eventName: banner.trackingKey,
                        tags: ["source": "wallet_home_ad_banner_button"]
                    )
                }
            }
        }
    }
    
    func walletBannerCell(_ cell: WalletBannerCell, requestDismiss banner: WalletBanner) {
        switch banner {
        case .embedded(let banner):
            switch banner {
            case .addWallet:
                BadgeManager.shared.setHasViewed(identifier: .addWalletBanner)
            }
        case .remote(let banner):
            AppGroupUserDefaults.Wallet.closedBannerIDs.append(banner.bannerID)
        }
        var snapshot = dataSource.snapshot()
        let identifiers = snapshot.itemIdentifiers(inSection: .banners)
        if identifiers.contains(.banner(banner)) {
            snapshot.deleteItems([.banner(banner)])
            if identifiers.count - 1 == 0 {
                snapshot.deleteSections([.banners])
            } else {
                bannersPageControl?.numberOfPages -= 1
            }
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
}

extension WalletViewController: WalletReferralCell.Delegate {
    
    func walletReferralCellDidSelectClose(_ cell: WalletReferralCell) {
        var snapshot = dataSource.snapshot()
        if snapshot.sectionIdentifiers.contains(.referral) {
            snapshot.deleteSections([.referral])
        }
        dataSource.apply(snapshot, animatingDifferences: true)
        BadgeManager.shared.setHasViewed(identifier: .walletHomeReferral)
    }
    
    func walletReferralCellDidSelectLearnMore(_ cell: WalletReferralCell) {
        UIApplication.homeContainerViewController?.presentReferralPage()
        BadgeManager.shared.setHasViewed(identifier: .referral)
    }
    
}
