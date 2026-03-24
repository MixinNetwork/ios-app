import UIKit
import MixinServices

final class PerpetualMarketViewController: UIViewController {
    
    private enum Section {
        case price
        case openPosition(PerpetualPositionViewModel)
        case info
        case closedPositions([PerpetualPositionViewModel])
        case introduction
    }
    
    private let wallet: Wallet
    private let positionsLoader: PerpetualPositionLoader
    private let marketLoader = PerpetualMarketLoader()
    private let candleLoader: PerpetualCandleLoader
    private let maxItemCount = 3
    
    private var viewModel: PerpetualMarketViewModel
    private var sections: [Section] = [.price, .info]
    private var selectedTimeFrame: PerpetualTimeFrame = .oneDay
    private var charts: [PerpetualTimeFrame: PerpetualMarketPriceCell.Chart] = [:]
    
    private weak var collectionView: UICollectionView!
    private weak var actionWrapperView: UIView!
    private weak var actionView: UIView?
    
    private weak var priceCell: PerpetualMarketPriceCell?
    
    private var openPositionViewModel: PerpetualPositionViewModel? {
        for section in sections {
            switch section {
            case .openPosition(let viewModel):
                return viewModel
            default:
                break
            }
        }
        return nil
    }
    
    init(
        wallet: Wallet,
        viewModel: PerpetualMarketViewModel,
    ) {
        self.wallet = wallet
        self.positionsLoader = PerpetualPositionLoader(
            walletID: wallet.tradingWalletID
        )
        self.candleLoader = PerpetualCandleLoader(
            marketID: viewModel.market.marketID
        )
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.candleLoader.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: viewModel.market.displaySymbol,
            subtitle: R.string.localizable.perpetual()
        )
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        view.backgroundColor = R.color.background_secondary()
        
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
                
                func multipleCells(estimatedHeight: CGFloat) -> NSCollectionLayoutSection {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(estimatedHeight)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = 20
                    return section
                }
                
                switch self?.sections[sectionIndex] {
                case .price, .none:
                    return oneCell(estimatedHeight: 358)
                case .openPosition:
                    return oneCell(estimatedHeight: 238)
                case .info:
                    let section = multipleCells(estimatedHeight: 50)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                    let background: NSCollectionLayoutDecorationItem = .background(
                        elementKind: TradeSectionBackgroundView.elementKind
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    section.decorationItems = [background]
                    return section
                case .closedPositions(let positions):
                    let section = multipleCells(estimatedHeight: 50)
                    let footerHeight: CGFloat = positions.count <= maxItemCount ? 20 : 56
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
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    let background: NSCollectionLayoutDecorationItem = .background(
                        elementKind: TradeSectionBackgroundView.elementKind
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    section.decorationItems = [background]
                    return section
                case .introduction:
                    return oneCell(estimatedHeight: 90)
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
        
        let actionWrapperView = UIView()
        view.addSubview(actionWrapperView)
        actionWrapperView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(collectionView.snp.bottom)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        actionWrapperView.backgroundColor = R.color.background_secondary()
        self.actionWrapperView = actionWrapperView
        
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        collectionView.register(
            R.nib.tradeSectionHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            TradeViewAllFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier
        )
        collectionView.register(R.nib.perpetualMarketPriceCell)
        collectionView.register(R.nib.perpetualMarketInfoCell)
        collectionView.register(R.nib.perpetualIntroductionCell)
        collectionView.register(R.nib.perpetualMarketOpenPositionCell)
        collectionView.register(R.nib.perpetualInactivePositionCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMarket(_:)),
            name: PerpsMarketDAO.marketsDidUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPositions),
            name: PerpsPositionDAO.perpsPositionDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadPositions),
            name: PerpsPositionHistoryDAO.perpsPositionHistoryDidSaveNotification,
            object: nil
        )
        reloadPositions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        positionsLoader.start()
        marketLoader.start()
        candleLoader.start(timeFrame: selectedTimeFrame)
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
        candleLoader.stop()
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "perps_market"])
    }
    
    @objc private func openPosition(_ sender: UIButton) {
        guard let actionView = actionView as? OpenPerpetualActionView else {
            return
        }
        let side: PerpetualOrderSide
        switch sender {
        case actionView.longButton:
            side = .long
        case actionView.shortButton:
            side = .short
        default:
            return
        }
        let open = OpenPerpetualPositionViewController(
            wallet: wallet,
            side: side,
            viewModel: viewModel
        )
        navigationController?.pushViewController(open, animated: true)
    }
    
    @objc private func closePosition(_ sender: UIButton) {
        guard let viewModel = openPositionViewModel else {
            return
        }
        let preview = ClosePerpetualPositionPreviewViewController(viewModel: viewModel)
        present(preview, animated: true)
    }
    
    @objc private func reloadMarket(_ notification: Notification) {
        let marketID = viewModel.market.marketID
        DispatchQueue.global().async { [weak self] in
            guard
                let market = PerpsMarketDAO.shared.market(marketID: marketID),
                let viewModel = PerpetualMarketViewModel(market: market)
            else {
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.viewModel = viewModel
                UIView.performWithoutAnimation(self.collectionView.reloadData)
            }
        }
    }
    
    @objc private func reloadPositions() {
        let marketID = viewModel.market.marketID
        DispatchQueue.global().async { [weak self, wallet] in
            let openPosition = PerpsPositionDAO.shared.position(marketID: marketID)
            let openPositionViewModel: PerpetualPositionViewModel? = if let openPosition {
                PerpetualPositionViewModel(wallet: wallet, position: openPosition)
            } else {
                nil
            }
            let closedPositions = PerpsPositionHistoryDAO.shared.historyItems(marketID: marketID)
                .map { history in
                    PerpetualPositionViewModel(wallet: wallet, history: history)
                }
            DispatchQueue.main.async {
                self?.reloadData(openPosition: openPositionViewModel, closedPositions: closedPositions)
            }
        }
    }
    
    private func reloadData(
        openPosition: PerpetualPositionViewModel?,
        closedPositions: [PerpetualPositionViewModel]
    ) {
        let actionViewToAdd: UIView?
        if let openPosition, openPosition.state != .opening {
            sections = [
                .price,
                .openPosition(openPosition),
                .info,
            ]
            if !closedPositions.isEmpty {
                sections.append(.closedPositions(closedPositions))
            }
            sections.append(.introduction)
            let actionView: AuthenticationPreviewSingleButtonTrayView
            if let view = self.actionView as? AuthenticationPreviewSingleButtonTrayView {
                actionView = view
                actionViewToAdd = nil
                actionView.button.removeTarget(self, action: nil, for: .touchUpInside)
            } else {
                actionView = AuthenticationPreviewSingleButtonTrayView()
                actionViewToAdd = actionView
                actionView.backgroundColor = R.color.background_secondary()
                actionView.button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 37, bottom: 12, right: 37)
            }
            actionView.button.setTitle(R.string.localizable.close_position(), for: .normal)
            actionView.button.addTarget(self, action: #selector(closePosition(_:)), for: .touchUpInside)
        } else {
            sections = [
                .price,
                .introduction,
                .info,
            ]
            if !closedPositions.isEmpty {
                sections.append(.closedPositions(closedPositions))
            }
            if openPosition == nil {
                if !(self.actionView is OpenPerpetualActionView) {
                    let view = R.nib.openPerpetualActionView(withOwner: nil)!
                    view.longButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
                    view.shortButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
                    view.isEnabled = true
                    actionViewToAdd = view
                } else {
                    actionViewToAdd = nil
                }
            } else {
                let actionView: AuthenticationPreviewSingleButtonTrayView
                if let view = self.actionView as? AuthenticationPreviewSingleButtonTrayView {
                    actionView = view
                    actionViewToAdd = nil
                    actionView.button.removeTarget(self, action: nil, for: .touchUpInside)
                } else {
                    actionView = AuthenticationPreviewSingleButtonTrayView()
                    actionViewToAdd = actionView
                    actionView.backgroundColor = R.color.background_secondary()
                    actionView.button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 37, bottom: 12, right: 37)
                }
                actionView.button.setTitle(R.string.localizable.perp_state_opening(), for: .normal)
                actionView.button.isEnabled = false
            }
        }
        if let actionView = actionViewToAdd {
            self.actionView?.removeFromSuperview()
            actionWrapperView.addSubview(actionView)
            actionView.snp.makeEdgesEqualToSuperview()
            self.actionView = actionView
        }
        collectionView.reloadData()
    }
    
    private func viewClosedPositions() {
        let positions = AllPerpetualPositionsViewController(wallet: wallet, content: .closed)
        navigationController?.pushViewController(positions, animated: true)
    }
    
}

extension PerpetualMarketViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension PerpetualMarketViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .price:
            1
        case .openPosition:
            1
        case .info:
            2
        case .closedPositions(let positions):
            positions.count
        case .introduction:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .price:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_price, for: indexPath)!
            cell.delegate = self
            cell.load(viewModel: viewModel)
            cell.load(chart: charts[selectedTimeFrame] ?? .loading)
            cell.setTimeFrame(frame: selectedTimeFrame)
            priceCell = cell
            return cell
        case .openPosition(let viewModel):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_open_position, for: indexPath)!
            cell.load(viewModel: viewModel)
            cell.delegate = self
            return cell
        case .info:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_info, for: indexPath)!
            switch indexPath.item {
            case 0:
                cell.titleLabel.text = R.string.localizable.volume_24h().uppercased()
                cell.contentLabel.text = viewModel.volume
            default:
                cell.titleLabel.text = R.string.localizable.funding_rate().uppercased()
                cell.contentLabel.text = viewModel.fundingRate
            }
            return cell
        case .closedPositions(let viewModels):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_inactive_position, for: indexPath)!
            let viewModel = viewModels[indexPath.item]
            cell.load(viewModel: viewModel)
            return cell
        case .introduction:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_introduction, for: indexPath)!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.trade_section_header, for: indexPath)!
            switch sections[indexPath.section] {
            case .closedPositions:
                view.label.text = R.string.localizable.perps_activity()
                view.onShowAll = { [weak self] (sender) in
                    self?.viewClosedPositions()
                }
            default:
                break
            }
            return view
        default:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TradeViewAllFooterView.reuseIdentifier, for: indexPath) as! TradeViewAllFooterView
            switch sections[indexPath.section] {
            case .closedPositions(let positions):
                view.viewAllButton.isHidden = positions.count <= maxItemCount
                view.onViewAll = { [weak self] (sender) in
                    self?.viewClosedPositions()
                }
            default:
                break
            }
            return view
        }
    }
    
}

extension PerpetualMarketViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .price, .openPosition, .info:
            false
        case .closedPositions, .introduction:
            true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .price, .openPosition, .info:
            break
        case .closedPositions(let viewModels):
            let viewModel = viewModels[indexPath.item]
            let position = PerpetualPositionViewController(wallet: wallet, viewModel: viewModel)
            navigationController?.pushViewController(position, animated: true)
        case .introduction:
            let manual = PerpsManual.viewController()
            present(manual, animated: true)
        }
    }
    
}

extension PerpetualMarketViewController: PerpetualMarketPriceCell.Delegate {
    
    func perpetualMarketPriceCell(_ cell: PerpetualMarketPriceCell, didSelectTimeFrame timeFrame: PerpetualTimeFrame) {
        self.selectedTimeFrame = timeFrame
        cell.load(chart: charts[timeFrame] ?? .loading)
        candleLoader.start(timeFrame: timeFrame)
    }
    
}

extension PerpetualMarketViewController: PerpetualMarketOpenPositionCell.Delegate {
    
    func perpetualMarketOpenPositionCellQuestionAboutSize(_ cell: PerpetualMarketOpenPositionCell) {
        let manual = PerpsManual.viewController(initialPage: .size)
        present(manual, animated: true)
    }
    
    func perpetualMarketOpenPositionCellAskToShare(_ cell: PerpetualMarketOpenPositionCell) {
        guard let positionViewModel = openPositionViewModel else {
            return
        }
        let share = SharePerpetualPositionViewController(
            viewModel: positionViewModel,
            latestPrice: viewModel.decimalPrice
        )
        present(share, animated: true)
    }
    
}

extension PerpetualMarketViewController: PerpetualCandleLoader.Delegate {
    
    func perpetualCandleLoader(
        _ loader: PerpetualCandleLoader,
        didLoadCandles candles: [PerpetualCandleViewModel]?,
        forTimeFrame timeFrame: PerpetualTimeFrame
    ) {
        let chart: PerpetualMarketPriceCell.Chart = if let candles {
            .candles(candles)
        } else {
            .unavailable
        }
        charts[timeFrame] = chart
        if selectedTimeFrame == timeFrame {
            priceCell?.load(chart: chart)
        }
    }
    
}
