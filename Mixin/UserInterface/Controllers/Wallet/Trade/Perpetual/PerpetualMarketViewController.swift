import UIKit
import MixinServices

final class PerpetualMarketViewController: UIViewController {
    
    private enum AutoClosingIntroDisplay {
        case takeProfit
        case stopLoss
        case disabled
    }
    
    private enum Section {
        case price
        case autoClosingIntroduction(PerpsAutoClosingCondition.Behavior)
        case openPosition(PerpetualPositionViewModel)
        case info
        case closedPositions([PerpetualPositionViewModel])
        case introduction
    }
    
    private let wallet: Wallet
    private let positionsLoader: PerpetualPositionLoader
    private let marketLoader: PerpetualMarketLoader
    private let candleLoader: PerpetualCandleLoader
    private let maxItemCount = 3
    private let autoClosingIntroductionDetectInterval: TimeInterval = 14 * .day
    
    private var viewModel: PerpetualMarketViewModel
    private var sections: [Section] = [.price, .info]
    private var selectedTimeFrame: PerpetualTimeFrame = .oneDay
    private var charts: [PerpetualTimeFrame: PerpetualMarketPriceCell.Chart] = [:]
    
    private weak var collectionView: UICollectionView!
    private weak var actionWrapperView: UIView!
    private weak var actionView: UIView?
    
    private weak var priceCell: PerpetualMarketPriceCell?
    private weak var autoClosingIntroCell: PerpsAutoClosingIntroCell?
    private weak var openPositionCell: PerpetualMarketOpenPositionCell?
    
    private var autoClosingIntroDisplay: AutoClosingIntroDisplay?
    private var isEditingTakeProfitPrice = false
    private var isEditingStopLossPrice = false
    
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
        self.marketLoader = PerpetualMarketLoader(
            marketID: viewModel.market.marketID
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
                case .autoClosingIntroduction:
                    return oneCell(estimatedHeight: 116)
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
        collectionView.register(R.nib.perpsAutoClosingIntroCell)
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
            sections = [.price]
            switch autoClosingIntroDisplay {
            case .takeProfit:
                sections.append(.autoClosingIntroduction(.takeProfit))
            case .stopLoss:
                sections.append(.autoClosingIntroduction(.stopLoss))
            case .disabled:
                break
            case .none:
                switch openPosition.pnlColor {
                case .rising:
                    if openPosition.takeProfitPrice == nil,
                       userDismissalOutdates(dismissalDate: AppGroupUserDefaults.Wallet.perpsOpenPositionTakeProfitDismissalDate)
                    {
                        sections.append(.autoClosingIntroduction(.takeProfit))
                        autoClosingIntroDisplay = .takeProfit
                    } else {
                        autoClosingIntroDisplay = .disabled
                    }
                case .falling:
                    if openPosition.stopLossPrice == nil,
                       userDismissalOutdates(dismissalDate: AppGroupUserDefaults.Wallet.perpsOpenPositionStopLossDismissalDate)
                    {
                        sections.append(.autoClosingIntroduction(.stopLoss))
                        autoClosingIntroDisplay = .stopLoss
                    } else {
                        autoClosingIntroDisplay = .disabled
                    }
                }
            }
            sections.append(contentsOf:[
                .openPosition(openPosition),
                .info,
            ])
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
            actionView.button.isEnabled = true
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
    
    private func handleTPSLUpdate(result: MixinAPI.Result<PerpetualPosition>) {
        var openPositionIndexPath: IndexPath? {
            for (index, section) in sections.enumerated() {
                switch section {
                case .openPosition:
                    return IndexPath(item: 0, section: index)
                default:
                    break
                }
            }
            return nil
        }
        switch result {
        case let .success(position):
            let item = PerpsPositionDAO.shared.save(position: position)
            if let item, let openPositionIndexPath {
                let viewModel = PerpetualPositionViewModel(wallet: wallet, position: item)
                self.sections[openPositionIndexPath.section] = .openPosition(viewModel)
                UIView.performWithoutAnimation {
                    collectionView.reloadItems(at: [openPositionIndexPath])
                }
            } else {
                var message = "TPSL: Item: \(item != nil), indexPath: \(openPositionIndexPath != nil)"
                if let item {
                    message += ", TP: \(item.takeProfitPrice ?? "null"), SL: \(item.stopLossPrice ?? "null")"
                }
                Logger.general.error(category: "PerpsMarket", message: message)
                reloadPositions()
            }
        case let .failure(error):
            showAutoHiddenHud(style: .error, text: error.localizedDescription)
            if let openPositionIndexPath {
                UIView.performWithoutAnimation {
                    collectionView.reloadItems(at: [openPositionIndexPath])
                }
            }
        }
        autoClosingIntroCell?.performSuggestionButton.isEnabled = true
        if !isEditingTakeProfitPrice && !isEditingStopLossPrice {
            positionsLoader.start()
        }
    }
    
    private func userDismissalOutdates(dismissalDate: Date) -> Bool {
        -dismissalDate.timeIntervalSinceNow > autoClosingIntroductionDetectInterval
    }
    
    private func setupTakeProfit(positionViewModel: PerpetualPositionViewModel) {
        guard let margin = positionViewModel.decimalMargin else {
            return
        }
        let editor = EditPerpClosingConditionViewController(
            viewModel: viewModel,
            side: positionViewModel.side,
            margin: margin,
            behavior: .takeProfit,
            leverage: Decimal(positionViewModel.leverageMultiplier),
            orderState: .open(entryPrice: positionViewModel.entryPrice),
            currentAutoClosingPrice: positionViewModel.takeProfitPrice
        )
        let priceFormatStyle = viewModel.market.canonicalPriceFormatStyle
        editor.onSet = { [weak self] price in
            if let self {
                positionsLoader.stop()
                isEditingTakeProfitPrice = true
                autoClosingIntroCell?.performSuggestionButton.isEnabled = false
                openPositionCell?.updateTakeProfit(busy: true)
            }
            let price: RouteAPI.AutoClosingPrice = if let price {
                .value(price.formatted(priceFormatStyle))
            } else {
                .delete
            }
            RouteAPI.updatePerpsTPSL(
                positionID: positionViewModel.positionID,
                takeProfitPrice: price,
                stopLossPrice: nil,
            ) { result in
                guard let self else {
                    return
                }
                self.isEditingTakeProfitPrice = false
                self.handleTPSLUpdate(result: result)
            }
        }
        present(editor, animated: true)
    }
    
    private func setupStopLoss(positionViewModel: PerpetualPositionViewModel) {
        guard let margin = positionViewModel.decimalMargin else {
            return
        }
        let editor = EditPerpClosingConditionViewController(
            viewModel: viewModel,
            side: positionViewModel.side,
            margin: margin,
            behavior: .stopLoss,
            leverage: Decimal(positionViewModel.leverageMultiplier),
            orderState: .open(entryPrice: positionViewModel.entryPrice),
            currentAutoClosingPrice: positionViewModel.stopLossPrice,
        )
        let priceFormatStyle = viewModel.market.canonicalPriceFormatStyle
        editor.onSet = { [weak self] price in
            if let self {
                positionsLoader.stop()
                isEditingStopLossPrice = true
                autoClosingIntroCell?.performSuggestionButton.isEnabled = false
                openPositionCell?.updateStopLoss(busy: true)
            }
            let price: RouteAPI.AutoClosingPrice = if let price {
                .value(price.formatted(priceFormatStyle))
            } else {
                .delete
            }
            RouteAPI.updatePerpsTPSL(
                positionID: positionViewModel.positionID,
                takeProfitPrice: nil,
                stopLossPrice: price,
            ) { result in
                guard let self else {
                    return
                }
                self.isEditingStopLossPrice = false
                self.handleTPSLUpdate(result: result)
            }
        }
        present(editor, animated: true)
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
        case .autoClosingIntroduction:
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
            cell.load(
                chart: charts[selectedTimeFrame] ?? .loading,
                priceFormatStyle: viewModel.userDisplayPriceFormatStyle
            )
            cell.setTimeFrame(frame: selectedTimeFrame)
            priceCell = cell
            return cell
        case .autoClosingIntroduction(let suggestion):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_auto_closing_intro, for: indexPath)!
            cell.suggestion = suggestion
            cell.delegate = self
            autoClosingIntroCell = cell
            return cell
        case .openPosition(let viewModel):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_open_position, for: indexPath)!
            cell.load(viewModel: viewModel)
            cell.updateTakeProfit(busy: isEditingTakeProfitPrice)
            cell.updateStopLoss(busy: isEditingStopLossPrice)
            cell.delegate = self
            openPositionCell = cell
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
        case .price, .autoClosingIntroduction, .openPosition, .info:
            false
        case .closedPositions, .introduction:
            true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .price, .autoClosingIntroduction, .openPosition, .info:
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
        cell.load(
            chart: charts[timeFrame] ?? .loading,
            priceFormatStyle: viewModel.userDisplayPriceFormatStyle
        )
        candleLoader.start(timeFrame: timeFrame)
    }
    
}

extension PerpetualMarketViewController: PerpetualMarketOpenPositionCell.Delegate {
    
    func perpetualMarketOpenPositionCell(_ cell: PerpetualMarketOpenPositionCell, requestManual page: PerpsManual.Page) {
        let manual = PerpsManual.viewController(initialPage: page)
        present(manual, animated: true)
    }
    
    func perpetualMarketOpenPositionCellAskToShare(_ cell: PerpetualMarketOpenPositionCell) {
        guard let positionViewModel = openPositionViewModel else {
            return
        }
        let latestPrice = viewModel.decimalPrice
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        Referral.loadAvailableCode { [weak self] code in
            hud.hide()
            let share = SharePerpetualPositionViewController(
                viewModel: positionViewModel,
                latestPrice: latestPrice,
                rebatingCode: code
            )
            self?.present(share, animated: true)
        }
    }
    
    func perpetualMarketOpenPositionCellRequestTakeProfit(_ cell: PerpetualMarketOpenPositionCell) {
        guard let positionViewModel = openPositionViewModel else {
            return
        }
        if positionViewModel.takeProfitPrice == nil {
            setupTakeProfit(positionViewModel: positionViewModel)
        } else {
            positionsLoader.stop()
            isEditingTakeProfitPrice = true
            autoClosingIntroCell?.performSuggestionButton.isEnabled = false
            cell.updateTakeProfit(busy: true)
            RouteAPI.updatePerpsTPSL(
                positionID: positionViewModel.positionID,
                takeProfitPrice: .delete,
                stopLossPrice: nil
            ) { [weak self] result in
                guard let self else {
                    return
                }
                self.isEditingTakeProfitPrice = false
                self.handleTPSLUpdate(result: result)
            }
        }
    }
    
    func perpetualMarketOpenPositionCellRequestStopLoss(_ cell: PerpetualMarketOpenPositionCell) {
        guard let positionViewModel = openPositionViewModel else {
            return
        }
        if positionViewModel.stopLossPrice == nil {
            setupStopLoss(positionViewModel: positionViewModel)
        } else {
            positionsLoader.stop()
            isEditingStopLossPrice = true
            autoClosingIntroCell?.performSuggestionButton.isEnabled = false
            cell.updateStopLoss(busy: true)
            RouteAPI.updatePerpsTPSL(
                positionID: positionViewModel.positionID,
                takeProfitPrice: nil,
                stopLossPrice: .delete
            ) { [weak self] result in
                guard let self else {
                    return
                }
                self.isEditingStopLossPrice = false
                self.handleTPSLUpdate(result: result)
            }
        }
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
            priceCell?.load(
                chart: chart,
                priceFormatStyle: viewModel.userDisplayPriceFormatStyle
            )
        }
    }
    
}

extension PerpetualMarketViewController: PerpsAutoClosingIntroCell.Delegate {
    
    func perpsAutoClosingIntroCell(_ cell: PerpsAutoClosingIntroCell, didRejectSuggestion suggestion: PerpsAutoClosingCondition.Behavior) {
        var autoClosingIntroSectionIndex: Int? {
            for (index, section) in sections.enumerated() {
                switch section {
                case .autoClosingIntroduction:
                    return index
                default:
                    break
                }
            }
            return nil
        }
        switch suggestion {
        case .takeProfit:
            AppGroupUserDefaults.Wallet.perpsOpenPositionTakeProfitDismissalDate = Date()
        case .stopLoss:
            AppGroupUserDefaults.Wallet.perpsOpenPositionStopLossDismissalDate = Date()
        }
        if let section = autoClosingIntroSectionIndex {
            autoClosingIntroDisplay = .disabled
            sections.remove(at: section)
            collectionView.deleteSections(IndexSet(integer: section))
        }
    }
    
    func perpsAutoClosingIntroCell(_ cell: PerpsAutoClosingIntroCell, didAcceptSuggestion suggestion: PerpsAutoClosingCondition.Behavior) {
        guard let positionViewModel = openPositionViewModel else {
            return
        }
        switch suggestion {
        case .takeProfit:
            setupTakeProfit(positionViewModel: positionViewModel)
        case .stopLoss:
            setupStopLoss(positionViewModel: positionViewModel)
        }
    }
    
}
