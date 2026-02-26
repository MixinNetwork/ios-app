import UIKit
import DGCharts
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
    private let viewModel: PerpetualMarketViewModel
    private let maxItemCount = 3
    
    private var sections: [Section] = [.price, .info]
    private var selectedTimeFrame: PerpetualTimeFrame = .day
    private var charts: [PerpetualTimeFrame: CandleChartData] = [:]
    
    private weak var collectionView: UICollectionView!
    private weak var actionWrapperView: UIView!
    private weak var actionView: UIView?
    
    private weak var priceCell: PerpetualMarketPriceCell?
    
    init(wallet: Wallet, viewModel: PerpetualMarketViewModel) {
        self.wallet = wallet
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: viewModel.market.displaySymbol,
            subtitle: "Perpetual"
        )
        
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
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        reloadPriceChartFromLocal(
            timeFrame: selectedTimeFrame,
            reloadFromRemoteAfterFinished: true
        )
        reloadPositions()
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
        present(open, animated: true)
    }
    
    @objc private func closePosition(_ sender: UIButton) {
        var viewModel: PerpetualPositionViewModel?
        for section in sections {
            switch section {
            case .openPosition(let v):
                viewModel = v
            default:
                break
            }
        }
        if let viewModel {
            let preview = ClosePerpetualPositionPreviewViewController(viewModel: viewModel)
            present(preview, animated: true)
        }
    }
    
    private func reloadData(
        openPosition: PerpetualPositionViewModel?,
        closedPositions: [PerpetualPositionViewModel]
    ) {
        var actionView: UIView?
        if let openPosition {
            sections = [
                .price,
                .openPosition(openPosition),
                .info,
                .closedPositions(closedPositions),
                .introduction,
            ]
            if !(self.actionView is AuthenticationPreviewSingleButtonTrayView) {
                let view = AuthenticationPreviewSingleButtonTrayView()
                view.button.setTitle("Close Position", for: .normal)
                view.button.addTarget(self, action: #selector(closePosition(_:)), for: .touchUpInside)
                actionView = view
            }
        } else {
            sections = [
                .price,
                .introduction,
                .info,
                .closedPositions(closedPositions),
            ]
            if !(self.actionView is OpenPerpetualActionView) {
                let view = R.nib.openPerpetualActionView(withOwner: nil)!
                view.longButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
                view.shortButton.addTarget(self, action: #selector(openPosition(_:)), for: .touchUpInside)
                view.isEnabled = true
                actionView = view
            }
        }
        if let actionView {
            self.actionView?.removeFromSuperview()
            actionWrapperView.addSubview(actionView)
            actionView.snp.makeEdgesEqualToSuperview()
            self.actionView = actionView
        }
        collectionView.reloadData()
    }
    
    private func reloadPositions() {
        let productID = viewModel.market.marketID
        DispatchQueue.global().async { [weak self, wallet] in
            let openPosition = PerpsPositionDAO.shared.position(productID: productID)
            let openPositionViewModel: PerpetualPositionViewModel? = if let openPosition {
                PerpetualPositionViewModel(wallet: wallet, position: openPosition)
            } else {
                nil
            }
            let closedPositions = PerpsPositionHistoryDAO.shared.historyItems(productID: productID)
                .map { history in
                    PerpetualPositionViewModel(wallet: wallet, history: history)
                }
            DispatchQueue.main.async {
                self?.reloadData(openPosition: openPositionViewModel, closedPositions: closedPositions)
            }
        }
    }
    
    private func reloadPriceChartFromLocal(
        timeFrame: PerpetualTimeFrame,
        reloadFromRemoteAfterFinished: Bool
    ) {
        DispatchQueue.global().async { [weak self, viewModel] in
            let candle = PerpsMarketCandlesDAO.shared.candle(
                product: viewModel.product,
                timeFrame: timeFrame.rawValue
            )
            let chart = candle?.asChartData()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if let chart {
                    self.load(chart: chart, for: timeFrame)
                }
                if reloadFromRemoteAfterFinished {
                    self.reloadPriceChartFromRemote(timeFrame: timeFrame)
                }
            }
        }
    }
    
    private func reloadPriceChartFromRemote(timeFrame: PerpetualTimeFrame) {
        RouteAPI.perpsMarketCandles(
            product: viewModel.product,
            timeFrame: timeFrame,
            queue: .global(),
        ) { [weak self] result in
            switch result {
            case .success(let candle):
                PerpsMarketCandlesDAO.shared.save(candle: candle)
                guard let chart = candle.asChartData() else {
                    return
                }
                DispatchQueue.main.async {
                    self?.load(chart: chart, for: timeFrame)
                }
            case .failure(let error):
                Logger.general.debug(category: "PerpetualMarket", message: "\(error)")
            }
        }
    }
    
    private func load(chart: CandleChartData, for timeFrame: PerpetualTimeFrame) {
        charts[timeFrame] = chart
        if selectedTimeFrame == timeFrame {
            priceCell?.load(chart: chart)
        }
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
            3
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
            cell.load(chart: charts[selectedTimeFrame])
            cell.setTimeFrame(frame: selectedTimeFrame)
            priceCell = cell
            return cell
        case .openPosition(let viewModel):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_open_position, for: indexPath)!
            cell.load(viewModel: viewModel)
            return cell
        case .info:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market_info, for: indexPath)!
            switch indexPath.item {
            case 0:
                cell.titleLabel.text = R.string.localizable.volume_24h().uppercased()
                cell.contentLabel.text = viewModel.market.volume
            case 1:
                cell.titleLabel.text = "未平仓合约"
                cell.contentLabel.text = "Under Construction"
            default:
                cell.titleLabel.text = "资金利率"
                cell.contentLabel.text = "Under Construction"
            }
            return cell
        case .closedPositions(let viewModels):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_closed_position, for: indexPath)!
            let viewModel = viewModels[indexPath.item]
            cell.load(viewModel: viewModel)
            return cell
        case .introduction:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_introduction, for: indexPath)!
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
        case .closedPositions:
            break
        case .introduction:
            break
        }
    }
    
}

extension PerpetualMarketViewController: PerpetualMarketPriceCell.Delegate {
    
    func perpetualMarketPriceCell(_ cell: PerpetualMarketPriceCell, didSelectTimeFrame timeFrame: PerpetualTimeFrame) {
        self.selectedTimeFrame = timeFrame
        if let chart = charts[timeFrame] {
            cell.load(chart: chart)
            reloadPriceChartFromRemote(timeFrame: timeFrame)
        } else {
            reloadPriceChartFromLocal(
                timeFrame: timeFrame,
                reloadFromRemoteAfterFinished: true
            )
        }
    }
    
}

fileprivate extension PerpetualMarketCandle {
    
    func asChartData() -> CandleChartData? {
        var entries: [CandleChartDataEntry] = []
        entries.reserveCapacity(items.count)
        for item in items {
            let open = NumberFormatter.enUSPOSIXLocalizedDecimal.number(from: item.open)?.doubleValue
            let close = NumberFormatter.enUSPOSIXLocalizedDecimal.number(from: item.close)?.doubleValue
            let high = NumberFormatter.enUSPOSIXLocalizedDecimal.number(from: item.high)?.doubleValue
            let low = NumberFormatter.enUSPOSIXLocalizedDecimal.number(from: item.low)?.doubleValue
            guard let open, let close, let high, let low else {
                return nil
            }
            let entry = CandleChartDataEntry(
                x: Double(item.timestamp),
                shadowH: high,
                shadowL: low,
                open: open,
                close: close
            )
            entries.append(entry)
        }
        let dataSet = CandleChartDataSet(entries: entries, label: "")
        dataSet.increasingColor = MarketColor.rising.uiColor
        dataSet.increasingFilled = true
        dataSet.decreasingColor = MarketColor.falling.uiColor
        dataSet.decreasingFilled = true
        dataSet.shadowColorSameAsCandle = true
        dataSet.barSpace = 0.3
        dataSet.drawValuesEnabled = false
        return CandleChartData(dataSet: dataSet)
    }
    
}
