import UIKit
import SafariServices
import OrderedCollections
import MixinServices

class WalletViewController: UIViewController, AssetChangeAccountRecoveryChecking {
    
    let itemsCount = 3
    let perpsTopMoversCount = 4
    let bannerController = AdvertisementBannerController(
        outlineInBannerCell: false,
        sectionBottomInset: 0,
    )
    
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
    
    var cashAccount: CashAccount?
    var earnAccount: EarnAccount?
    
    var walletActionHandler: (any WalletActionHandler)?
    
    private(set) weak var titleView: UIView!
    private(set) weak var titleInfoStackView: UIStackView!
    private(set) weak var walletSwitchImageView: UIImageView!
    private(set) weak var titleLabel: UILabel!
    private(set) weak var collectionView: UICollectionView!
    
    private(set) var isViewAppearing = false
    private(set) var dataSource: DiffableDataSource!
    
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
        
        let walletSwitchImageView = UIImageView(image: R.image.hamburger())
        walletSwitchImageView.tintColor = R.color.icon_tint()
        walletSwitchImageView.contentMode = .center
        walletSwitchImageView.snp.makeConstraints { make in
            make.width.equalTo(24)
        }
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = R.color.text()
        let titleInfoStackView = UIStackView(
            arrangedSubviews: [walletSwitchImageView, titleLabel]
        )
        titleInfoStackView.axis = .horizontal
        titleInfoStackView.alignment = .center
        titleInfoStackView.spacing = 8
        titleInfoStackView.addArrangedSubview(walletSwitchImageView)
        titleInfoStackView.addArrangedSubview(titleLabel)
        let titleView = UIView()
        titleView.addSubview(titleInfoStackView)
        titleInfoStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let switchButton = UIButton(type: .custom)
        switchButton.addTarget(
            self,
            action: #selector(switchFromWallets(_:)),
            for: .touchUpInside
        )
        titleView.addSubview(switchButton)
        switchButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let titleItem = UIBarButtonItem(customView: titleView)
        if #available(iOS 26.0, *) {
            titleItem.hidesSharedBackground = true
        }
        navigationItem.leftBarButtonItem = titleItem
        self.titleView = titleView
        self.titleInfoStackView = titleInfoStackView
        self.walletSwitchImageView = walletSwitchImageView
        self.titleLabel = titleLabel
        
        let searchItem = UIBarButtonItem.tintedIcon(
            image: R.image.ic_title_search(),
            target: self,
            action: #selector(searchAction(_:)),
        )
        let scanItem = UIBarButtonItem.tintedIcon(
            image: R.image.ic_app_category_scan(),
            target: self,
            action: #selector(scanQRCode),
        )
        let moreItem = UIBarButtonItem.tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(moreAction(_:)),
        )
        navigationItem.rightBarButtonItems = [
            moreItem,
            scanItem,
            searchItem,
        ]
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, environment in
                guard let self, let section = self.dataSource.sectionIdentifier(for: sectionIndex) else {
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
                    if case .importSecret = self.overviewAction {
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
                    return self.bannerController.layoutSection(environment: environment)
                case .valueAddedServices:
                    let servicesCount = self.dataSource.snapshot().numberOfItems(inSection: .valueAddedServices)
                    switch servicesCount {
                    case 1:
                        let section = singleItem(estimatedHeight: 86)
                        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                        return section
                    default:
                        let section: NSCollectionLayoutSection
                        if #available(iOS 17.0, *) {
                            let itemSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .uniformAcrossSiblings(estimate: 96)
                            )
                            let item = NSCollectionLayoutItem(layoutSize: itemSize)
                            let groupSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .estimated(110)
                            )
                            let group = NSCollectionLayoutGroup.horizontal(
                                layoutSize: groupSize,
                                subitem: item,
                                count: 2
                            )
                            group.interItemSpacing = .fixed(11)
                            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                            section = NSCollectionLayoutSection(group: group)
                        } else {
                            let itemSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .fractionalHeight(1)
                            )
                            let item = NSCollectionLayoutItem(layoutSize: itemSize)
                            let groupSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .estimated(96)
                            )
                            let group = NSCollectionLayoutGroup.horizontal(
                                layoutSize: groupSize,
                                subitem: item,
                                count: 2
                            )
                            group.interItemSpacing = .fixed(11)
                            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                            section = NSCollectionLayoutSection(group: group)
                        }
                        section.interGroupSpacing = 10
                        return section
                    }
                case .perpsPositions:
                    return listSection(
                        showFooter: self.hasMorePerpsPositions,
                        trailingSwipeActionsConfigurationProvider: nil
                    )
                case .tokens:
                    return listSection(
                        showFooter: self.hasMoreTokens
                    ) { [weak self] indexPath in
                        self?.hideTokenAction(indexPath: indexPath)
                    }
                case .transactions:
                    return listSection(
                        showFooter: self.hasMoreTransactions,
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
        collectionView.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let emptyWalletInstructionRegistration = UICollectionView.CellRegistration<EmptyWalletInstructionCell, Void>(
            cellNib: UINib(resource: R.nib.emptyWalletInstructionCell)
        ) { [weak self] cell, indexPath, _ in
            cell.delegate = self
        }
        let bannerRegistration = bannerController.bannerCellRegistration()
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
            case let .banner(banner, _):
                return collectionView.dequeueConfiguredReusableCell(using: bannerRegistration, for: indexPath, item: banner)
            case .cash:
                guard let self else {
                    return nil
                }
                let cell = self.dequeueValueAddedServiceCell(indexPath: indexPath)
                cell.load(account: cashAccount)
                return cell
            case .earn:
                guard let self else {
                    return nil
                }
                let cell = self.dequeueValueAddedServiceCell(indexPath: indexPath)
                cell.load(account: earnAccount)
                return cell
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
                return nil
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
                    header.titleLabel.text = R.string.localizable.assets()
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
        collectionView.register(R.nib.largeWalletValueAddedServiceCell)
        collectionView.register(R.nib.mediumWalletValueAddedServiceCell)
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
        
        bannerController.delegate = self
        bannerController.attach(collectionView: collectionView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isViewAppearing = true
        bannerController.viewWillAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewAppearing = false
        bannerController.viewWillDisappear()
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
        UIApplication.shared.homeNavigationController?.pushQRCodeScannerViewController()
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
            let customerService = CustomerServiceViewController(reportingTags: nil)
            present(customerService, animated: true)
        case .helpCenter:
            let safari = SFSafariViewController(url: .support)
            present(safari, animated: true)
        }
    }
    
    func configure(tokenCell: TokenCell, withTokenOf assetID: String) {
        
    }
    
    func configure(transactionCell: TransactionCell, withTransactionOf id: String) {
        
    }
    
    func reload(cashAccount: CashAccount?) {
        
    }
    
    func reload(earnAccount: EarnAccount) {
        
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
    
    private func dequeueValueAddedServiceCell(indexPath: IndexPath) -> any WalletValueAddedServiceCell {
        let servicesCount = dataSource.snapshot().numberOfItems(inSection: .valueAddedServices)
        switch servicesCount {
        case 1:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.large_wallet_vas, for: indexPath)!
        default:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.medium_wallet_vas, for: indexPath)!
        }
    }
    
}

extension WalletViewController {
    
    enum Section {
        case overview
        case emptyWalletInstruction
        case banners
        case valueAddedServices
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
        case banner(AdvertisementBanner, duplicationOffset: Int)
        case cash
        case earn
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
    
}

extension WalletViewController {
    
    func insertReferralSection(into snapshot: inout DataSourceSnapshot) {
        guard !BadgeManager.shared.hasViewed(identifier: .walletHomeReferral) else {
            return
        }
        snapshot.insertSections([.referral], beforeSection: .support)
        snapshot.appendItems([.referral], toSection: .referral)
    }
    
}

extension WalletViewController {
    
    // nil for all chains
    func reloadBannersIfAllowed(chainIDs: Set<String>?) {
        bannerController.reloadBannersIfAllowed(
            chainIDs: chainIDs
        ) { [weak self] availableBanners in
            guard let self else {
                return
            }
            self.applySnapshot(
                self.dataSource.snapshot(),
                remoteBanners: availableBanners,
                mode: .differences(animated: false),
            )
        }
    }
    
    func applySnapshot(
        _ snapshot: DataSourceSnapshot,
        remoteBanners: [AppBanner],
        mode: AdvertisementBannerController.SnapshotUpdate,
    ) {
        var banners: [AdvertisementBanner] = remoteBanners.compactMap { banner in
            switch banner.placement.knownCase {
            case .wallet:
                .remote(banner)
            case .none, .marketCrypto, .marketPerps, .marketStock:
                .none
            }
        }
        if !BadgeManager.shared.hasViewed(identifier: .addWalletBanner) {
            banners.append(.embedded(.addWallet))
        }
        bannerController.update(
            placement: .wallet,
            banners: banners,
            snapshot: snapshot,
            dataSource: dataSource,
            section: .banners,
            position: .after(.overview),
            itemConstructor: { Item.banner($0, duplicationOffset: $1) },
            mode: mode,
            completion: nil,
        )
    }
    
}

extension WalletViewController {
    
    func reloadCashAccount() {
        CashAPI.account { [weak self] result in
            switch result {
            case .success(let account):
                DispatchQueue.global().async {
                    PropertiesDAO.shared.set(jsonObject: account, forKey: .cashAccount)
                }
                self?.reload(cashAccount: account)
            case .failure(.response(.notFound)):
                Logger.general.debug(category: "Wallet", message: "No cash account")
                DispatchQueue.global().async {
                    PropertiesDAO.shared.removeValue(forKey: .cashAccount)
                }
                self?.reload(cashAccount: nil)
            case .failure(let error):
                Logger.general.debug(category: "Wallet", message: "\(error)")
                // Don't overwrite local account on network error
            }
        }
    }
    
    func insertOrUpdate(
        vasItem: Item,
        into snapshot: inout DataSourceSnapshot,
    ) {
        if snapshot.sectionIdentifiers.contains(.valueAddedServices) {
            let existingItems = snapshot.itemIdentifiers(inSection: .valueAddedServices)
            if existingItems.contains(vasItem) {
                snapshot.reconfigureItems([vasItem])
            } else {
                if vasItem == .cash, existingItems.contains(.earn) {
                    snapshot.insertItems([.cash], beforeItem: .earn)
                } else {
                    snapshot.appendItems([vasItem], toSection: .valueAddedServices)
                }
                if !existingItems.isEmpty {
                    snapshot.reloadItems(existingItems)
                }
            }
        } else {
            if snapshot.sectionIdentifiers.contains(.banners) {
                snapshot.insertSections([.valueAddedServices], afterSection: .banners)
            } else if let firstSection = snapshot.sectionIdentifiers.first {
                snapshot.insertSections([.valueAddedServices], afterSection: firstSection)
            } else {
                snapshot.appendSections([.valueAddedServices])
            }
            snapshot.appendItems([vasItem], toSection: .valueAddedServices)
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

extension WalletViewController: AdvertisementBannerController.Delegate {
    
    func advertisementBannerController(
        _ controller: AdvertisementBannerController,
        requestAction action: AdvertisementBanner.Action,
        for banner: AdvertisementBanner,
    ) {
        switch banner {
        case .embedded(.addWallet):
            switch action {
            case .background:
                return
            case .button:
                BadgeManager.shared.setHasViewed(identifier: .addWalletAction)
                let selector = AddWalletMethodSelectorViewController()
                selector.onSelected = { [weak self] method in
                    let introduction = AddWalletIntroductionViewController(action: .addWallet(method))
                    self?.navigationController?.pushViewController(introduction, animated: true)
                }
                present(selector, animated: true)
            }
        case .remote(let remote):
            let source = switch action {
            case .button:
                "ad_banner_button"
            case .background:
                "ad_banner_background"
            }
            AdvertisementBannerActionHandler.perform(action, for: remote, source: source)
        }
    }
    
    func advertisementBannerController(
        _ controller: AdvertisementBannerController,
        requestDismiss banner: AdvertisementBanner,
    ) {
        switch banner {
        case .embedded(.addWallet):
            BadgeManager.shared.setHasViewed(identifier: .addWalletBanner)
        case .remote(let remote):
            AdvertisementBannerActionHandler.dismiss(remote)
        }
        bannerController.update(
            placement: .wallet,
            banners: controller.banners.filter { $0 != banner },
            snapshot: dataSource.snapshot(),
            dataSource: dataSource,
            section: .banners,
            position: .after(.overview),
            itemConstructor: { Item.banner($0, duplicationOffset: $1) },
            mode: .differences(animated: true),
            completion: nil,
        )
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
        UIApplication.shared.homeNavigationController?.presentReferralPage()
        BadgeManager.shared.setHasViewed(identifier: .referral)
    }
    
}
