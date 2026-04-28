import UIKit
import MixinServices

final class TradePerpetualViewController: UIViewController {
    
    var tradingWalletID: String {
        wallet.tradingWalletID
    }
    
    private weak var collectionView: UICollectionView!
    private weak var actionView: OpenPerpetualActionView!
    
    private let wallet: Wallet
    private let positionsLoader: PerpetualPositionLoader
    private let marketLoader = PerpetualMarketLoader(marketID: nil)
    private let maxItemCount = 3
    
    private var sections: [Section] = []
    private var value: PerpetualPositionValue?
    private var openPositions: [PerpetualPositionViewModel] = []
    private var markets: [PerpetualMarketViewModel]?
    private var hasHistoryLoadedFromRemote = false
    private var closedPositions: [PerpetualPositionViewModel]?
    
    init(
        wallet: Wallet,
    ) {
        self.wallet = wallet
        self.positionsLoader = PerpetualPositionLoader(
            walletID: wallet.tradingWalletID
        )
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self, maxItemCount] (sectionIndex, environment) in
                
                func oneCell(estimatedHeight: CGFloat) -> NSCollectionLayoutSection {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(estimatedHeight)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                }
                
                func multipleCells(itemCount: Int?) -> NSCollectionLayoutSection {
                    let itemSize = if let itemCount, itemCount != 0 {
                        NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(50)
                        )
                    } else {
                        NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(195)
                        )
                    }
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = 20
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    
                    let footerHeight: CGFloat = (itemCount ?? 0) <= maxItemCount ? 20 : 56
                    section.boundarySupplementaryItems = [
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .absolute(57)
                            ),
                            elementKind: UICollectionView.elementKindSectionHeader,
                            alignment: .top
                        ),
                        NSCollectionLayoutBoundarySupplementaryItem(
                            layoutSize: NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .absolute(footerHeight)
                            ),
                            elementKind: UICollectionView.elementKindSectionFooter,
                            alignment: .bottom
                        ),
                    ]
                    
                    let background: NSCollectionLayoutDecorationItem = .background(
                        elementKind: TradeSectionBackgroundView.elementKind
                    )
                    background.contentInsets = section.contentInsets
                    section.decorationItems = [background]
                    
                    return section
                }
                
                return switch self?.sections[sectionIndex] {
                case .none, .value:
                    oneCell(estimatedHeight: 97)
                case .positions:
                    multipleCells(itemCount: self?.openPositions.count)
                case .markets:
                    multipleCells(itemCount: self?.markets?.count)
                case .activity:
                    multipleCells(itemCount: self?.closedPositions?.count)
                case .introduction:
                    oneCell(estimatedHeight: 90)
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
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        self.collectionView = collectionView
        
        let actionView = R.nib.openPerpetualActionView(withOwner: nil)!
        view.addSubview(actionView)
        actionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(collectionView.snp.bottom)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        actionView.longButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
        actionView.shortButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
        actionView.isEnabled = false
        self.actionView = actionView
        
        collectionView.register(
            R.nib.tradeSectionHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            TradeViewAllFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier
        )
        collectionView.register(R.nib.perpetualPositionValueCell)
        collectionView.register(R.nib.perpetualPlaceholderCell)
        collectionView.register(R.nib.perpetualMarketCell)
        collectionView.register(R.nib.perpetualInactivePositionCell)
        collectionView.register(R.nib.perpetualIntroductionCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadOpenPositions(_:)),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMarkets(_:)),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadClosedPositions(_:)),
            name: PerpsPositionHistoryDAO.perpsPositionHistoryDidSaveNotification,
            object: nil
        )
        
        let limit = maxItemCount + 1
        DispatchQueue.global().async { [weak self, wallet] in
            let value = PerpsPositionDAO.shared.positionValue()
            let openPositions = PerpsPositionDAO.shared.positionItems()
                .map { item in
                    PerpetualPositionViewModel(wallet: wallet, position: item)
                }
            let markets = PerpsMarketDAO.shared.availableMarkets(ordering: nil, limit: limit)
            let marketViewModels = markets.compactMap(PerpetualMarketViewModel.init(market:))
            let closedPositions = PerpsPositionHistoryDAO.shared.historyItems(
                offsetClosedAt: nil,
                limit: limit
            ).map { history in
                PerpetualPositionViewModel(wallet: wallet, history: history)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.value = value
                self.openPositions = openPositions
                if !marketViewModels.isEmpty {
                    self.markets = marketViewModels
                    self.actionView.isEnabled = true
                }
                self.closedPositions = closedPositions
                self.sections = Section.sections(openPositionCount: openPositions.count)
                UIView.performWithoutAnimation(self.collectionView.reloadData)
                self.positionsLoader.start()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        positionsLoader.start()
        marketLoader.start()
        if !BadgeManager.shared.hasViewed(identifier: .perpsManual) {
            BadgeManager.shared.setHasViewed(identifier: .perpsManual)
            let manual = PerpsManual.viewController()
            present(manual, animated: true)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        positionsLoader.stop()
        marketLoader.stop()
    }
    
    @objc private func openPosition(_ sender: UIButton) {
        let side: PerpetualOrderSide
        switch sender {
        case actionView.longButton:
            side = .long
        case actionView.shortButton:
            side = .short
        default:
            return
        }
        let selector = PerpetualMarketSelectorViewController()
        selector.onSelected = { [wallet, weak self] (viewModel) in
            guard let self else {
                return
            }
            let alreadyOpened = self.openPositions.contains { position in
                position.marketID == viewModel.market.marketID
            }
            self.dismiss(animated: true) {
                if alreadyOpened {
                    let market = PerpetualMarketViewController(
                        wallet: self.wallet,
                        viewModel: viewModel
                    )
                    self.navigationController?.pushViewController(market, animated: true)
                } else {
                    let open = OpenPerpetualPositionViewController(
                        wallet: wallet,
                        side: side,
                        viewModel: viewModel,
                    )
                    self.navigationController?.pushViewController(open, animated: true)
                }
            }
        }
        present(selector, animated: true)
    }
    
}

extension TradePerpetualViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .value, .introduction:
            1
        case .positions:
            min(maxItemCount, openPositions.count)
        case .markets:
            if let count = markets?.count, count != 0 {
                min(maxItemCount, count)
            } else {
                1
            }
        case .activity:
            if let count = closedPositions?.count, count != 0 {
                min(maxItemCount, count)
            } else {
                1
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .value:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_positions_value, for: indexPath)!
            cell.loadOpenPositions(value: value)
            return cell
        case .positions:
            let position = openPositions[indexPath.item]
            switch position.state {
            case .opening:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_inactive_position, for: indexPath)!
                cell.load(viewModel: position)
                return cell
            default:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                cell.load(viewModel: position)
                return cell
            }
        case .markets:
            if let markets, !markets.isEmpty {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                let viewModel = markets[indexPath.item]
                cell.load(viewModel: viewModel)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_placeholder, for: indexPath)!
                if markets == nil {
                    cell.activityIndicatorView.startAnimating()
                    cell.emptyIndicatorStackView.isHidden = true
                } else {
                    cell.activityIndicatorView.stopAnimating()
                    cell.titleLabel.text = R.string.localizable.no_results().uppercased()
                    cell.emptyIndicatorStackView.isHidden = false
                    cell.onHelp = { [weak self] in
                        self?.presentPerpsManual()
                    }
                }
                return cell
            }
        case .activity:
            if let closedPositions, !closedPositions.isEmpty {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_inactive_position, for: indexPath)!
                let viewModel = closedPositions[indexPath.item]
                cell.load(viewModel: viewModel)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_placeholder, for: indexPath)!
                if closedPositions == nil {
                    cell.activityIndicatorView.startAnimating()
                    cell.emptyIndicatorStackView.isHidden = true
                } else {
                    cell.activityIndicatorView.stopAnimating()
                    cell.titleLabel.text = R.string.localizable.no_activity().uppercased()
                    cell.emptyIndicatorStackView.isHidden = false
                    cell.onHelp = { [weak self] in
                        self?.presentPerpsManual()
                    }
                }
                return cell
            }
        case .introduction:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_introduction, for: indexPath)!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
            switch sections[indexPath.section] {
            case .value, .introduction:
                break
            case .positions:
                view.label.text = R.string.localizable.positions_count(openPositions.count)
                view.onShowAll = { [weak self] (sender) in
                    self?.viewOpenPositions()
                }
            case .markets:
                view.label.text = R.string.localizable.perps_markets()
                view.onShowAll = { [weak self] (sender) in
                    self?.viewAllMarkets()
                }
            case .activity:
                view.label.text = R.string.localizable.perps_activity()
                view.onShowAll = { [weak self] (sender) in
                    self?.viewClosedPositions()
                }
            }
            return view
        default:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier, for: indexPath) as! TradeViewAllFooterView
            switch sections[indexPath.section] {
            case .value, .introduction:
                break
            case .positions:
                view.viewAllButton.isHidden = openPositions.count <= maxItemCount
                view.onViewAll = { [weak self] (sender) in
                    self?.viewOpenPositions()
                }
            case .markets:
                view.viewAllButton.isHidden = (markets?.count ?? 0) <= maxItemCount
                view.onViewAll = { [weak self] (sender) in
                    self?.viewAllMarkets()
                }
            case .activity:
                view.viewAllButton.isHidden = (closedPositions?.count ?? 0) <= maxItemCount
                view.onViewAll = { [weak self] (sender) in
                    self?.viewClosedPositions()
                }
            }
            return view
        }
    }
    
}

extension TradePerpetualViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .value:
            break
        case .positions:
            let position = openPositions[indexPath.item]
            if let market = PerpsMarketDAO.shared.market(marketID: position.marketID),
               let viewModel = PerpetualMarketViewModel(market: market)
            {
                let market = PerpetualMarketViewController(
                    wallet: wallet,
                    viewModel: viewModel,
                )
                navigationController?.pushViewController(market, animated: true)
            }
        case .markets:
            guard let markets, !markets.isEmpty else {
                return
            }
            let viewModel = markets[indexPath.item]
            let market = PerpetualMarketViewController(
                wallet: wallet,
                viewModel: viewModel,
            )
            navigationController?.pushViewController(market, animated: true)
        case .activity:
            guard let closedPositions, !closedPositions.isEmpty else {
                return
            }
            let viewModel = closedPositions[indexPath.item]
            let position = PerpetualPositionViewController(wallet: wallet, viewModel: viewModel)
            navigationController?.pushViewController(position, animated: true)
        case .introduction:
            presentPerpsManual()
        }
    }
    
}

extension TradePerpetualViewController {
    
    private enum Section {
        
        case value
        case positions
        case markets
        case activity
        case introduction
        
        static func sections(openPositionCount: Int) -> [Section] {
            var sections: [Section] = [
                .value,
                .markets,
                .activity,
            ]
            if openPositionCount == 0 {
                sections.insert(.introduction, at: 1)
            } else {
                sections.insert(.positions, at: 1)
                sections.append(.introduction)
            }
            return sections
        }
        
    }
    
    private func viewOpenPositions() {
        let positions = AllPerpetualPositionsViewController(wallet: wallet, content: .open)
        navigationController?.pushViewController(positions, animated: true)
    }
    
    private func viewAllMarkets() {
        let selector = PerpetualMarketSelectorViewController()
        selector.onSelected = { [wallet, weak self] (viewModel) in
            guard let self else {
                return
            }
            self.dismiss(animated: true) {
                let market = PerpetualMarketViewController(
                    wallet: wallet,
                    viewModel: viewModel,
                )
                self.navigationController?.pushViewController(market, animated: true)
            }
        }
        present(selector, animated: true)
    }
    
    private func viewClosedPositions() {
        let positions = AllPerpetualPositionsViewController(wallet: wallet, content: .closed)
        navigationController?.pushViewController(positions, animated: true)
    }
    
    private func presentPerpsManual() {
        let manual = PerpsManual.viewController()
        present(manual, animated: true)
    }
    
    @objc private func reloadOpenPositions(_ notification: Notification) {
        DispatchQueue.global().async { [weak self, wallet] in
            let value = PerpsPositionDAO.shared.positionValue()
            let openPositions = PerpsPositionDAO.shared.positionItems()
                .map { item in
                    PerpetualPositionViewModel(wallet: wallet, position: item)
                }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.value = value
                self.openPositions = openPositions
                let sectionsBefore = self.sections
                let sectionsAfter = Section.sections(openPositionCount: openPositions.count)
                self.sections = sectionsAfter
                UIView.performWithoutAnimation {
                    if sectionsBefore == sectionsAfter {
                        var sections = IndexSet()
                        for (index, section) in self.sections.enumerated() {
                            switch section {
                            case .value, .positions:
                                sections.insert(index)
                            default:
                                break
                            }
                        }
                        self.collectionView.reloadSections(sections)
                    } else {
                        self.collectionView.reloadData()
                    }
                }
            }
        }
    }
    
    @objc private func reloadMarkets(_ notification: Notification) {
        let limit = maxItemCount + 1
        let walletID = wallet.tradingWalletID
        DispatchQueue.global().async { [weak self] in
            let markets = PerpsMarketDAO.shared.availableMarkets(
                ordering: nil,
                limit: limit
            )
            let viewModels = markets.compactMap(
                PerpetualMarketViewModel.init(market:)
            )
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.markets = viewModels
                if let section = self.sections.firstIndex(of: .markets) {
                    UIView.performWithoutAnimation {
                        let markets = IndexSet(integer: section)
                        self.collectionView.reloadSections(markets)
                    }
                }
                self.actionView.isEnabled = !viewModels.isEmpty
                if !self.hasHistoryLoadedFromRemote {
                    // Load history only once, but after the markets
                    // are loaded, to avoid missing symbols in history
                    self.hasHistoryLoadedFromRemote = true
                    let history = SyncPerpsPositionHistoryJob(walletID: walletID)
                    ConcurrentJobQueue.shared.addJob(job: history)
                }
            }
        }
    }
    
    @objc private func reloadClosedPositions(_ notification: Notification) {
        let limit = maxItemCount + 1
        DispatchQueue.global().async { [weak self, wallet] in
            let closedPositions = PerpsPositionHistoryDAO.shared.historyItems(
                offsetClosedAt: nil,
                limit: limit
            ).map { history in
                PerpetualPositionViewModel(wallet: wallet, history: history)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.closedPositions = closedPositions
                if let section = self.sections.firstIndex(of: .activity) {
                    UIView.performWithoutAnimation {
                        let activity = IndexSet(integer: section)
                        self.collectionView.reloadSections(activity)
                    }
                }
            }
        }
    }
    
}
