import UIKit
import MixinServices

final class AllPerpetualPositionsViewController: UIViewController {
    
    private enum Section {
        case summary
        case positions
    }
    
    private let wallet: Wallet
    private let content: PerpetualPositionType
    private let positionsLoader: PerpetualPositionLoader
    private let sections: [Section]
    private let pageCount = 50
    
    private weak var collectionView: UICollectionView!
    
    private var value: PerpetualPositionValue?
    private var viewModels: [PerpetualPositionViewModel]?
    private var loadNextPageIndexPath: IndexPath?
    
    init(wallet: Wallet, content: PerpetualPositionType) {
        self.wallet = wallet
        self.content = content
        self.positionsLoader = PerpetualPositionLoader(
            walletID: wallet.tradingWalletID
        )
        self.sections = switch content {
        case .open:
            [.summary, .positions]
        case .closed:
            [.positions]
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = switch content {
        case .open:
            R.string.localizable.positions()
        case .closed:
            R.string.localizable.perps_activity()
        }
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] (sectionIndex, _) in
                switch self?.sections[sectionIndex] {
                case .none, .summary:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(97))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .positions:
                    let hasPositions = if let viewModels = self?.viewModels {
                        !viewModels.isEmpty
                    } else {
                        false
                    }
                    let itemSize = if hasPositions {
                        NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                    } else {
                        NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(200))
                    }
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                    section.interGroupSpacing = 20
                    if hasPositions {
                        let background: NSCollectionLayoutDecorationItem = .background(
                            elementKind: TradeSectionBackgroundView.elementKind
                        )
                        background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                        section.decorationItems = [background]
                    }
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
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
        collectionView.register(R.nib.perpetualPositionValueCell)
        collectionView.register(R.nib.perpetualMarketCell)
        collectionView.register(R.nib.perpetualInactivePositionCell)
        collectionView.register(R.nib.perpetualPlaceholderCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        switch content {
        case .open:
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reloadData),
                name: PerpsPositionDAO.perpsPositionDidChangeNotification,
                object: nil
            )
        case .closed:
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reloadData),
                name: PerpsPositionHistoryDAO.perpsPositionHistoryDidSaveNotification,
                object: nil
            )
        }
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        positionsLoader.start()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        positionsLoader.stop()
    }
    
    @objc private func reloadData() {
        switch content {
        case .open:
            DispatchQueue.global().async { [wallet, weak self] in
                let value = PerpsPositionDAO.shared.positionValue()
                let viewModels = PerpsPositionDAO.shared.positionItems().map { item in
                    PerpetualPositionViewModel(wallet: wallet, position: item)
                }
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.value = value
                    self.viewModels = viewModels
                    self.collectionView.reloadData()
                }
            }
        case .closed:
            loadNextPageIndexPath = nil
            loadNextPage(offset: nil)
        }
    }
    
    private func loadNextPage(offset: String?) {
        DispatchQueue.global().async { [wallet, pageCount, weak self] in
            let viewModels = PerpsPositionHistoryDAO.shared.historyItems(
                offsetClosedAt: offset,
                limit: pageCount
            ).map { item in
                PerpetualPositionViewModel(wallet: wallet, history: item)
            }
            let hasMore = viewModels.count == pageCount
            if offset != nil, viewModels.isEmpty {
                // Last page is empty
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let itemsBefore = self.viewModels ?? []
                let itemsCountBefore = itemsBefore.count
                if offset == nil || itemsCountBefore == 0 || viewModels.count == 0 {
                    self.viewModels = viewModels
                    self.collectionView.reloadData()
                } else if let section = self.sections.firstIndex(of: .positions) {
                    let itemsAfter = itemsBefore + viewModels
                    let itemsCountAfter = itemsAfter.count
                    self.viewModels = itemsAfter
                    let items = (itemsCountBefore..<itemsCountAfter).map { item in
                        IndexPath(item: item, section: section)
                    }
                    UIView.performWithoutAnimation {
                        self.collectionView.insertItems(at: items)
                    }
                } else {
                    assertionFailure("Not expected to happen. There should be a section for positions")
                    self.viewModels = viewModels
                    self.collectionView.reloadData()
                }
                if hasMore,
                   let section = self.sections.firstIndex(of: .positions),
                   let count = self.viewModels?.count
                {
                    self.loadNextPageIndexPath = IndexPath(item: count - 3, section: section)
                }
            }
        }
    }
    
}

extension AllPerpetualPositionsViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AllPerpetualPositionsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .summary:
            1
        case .positions:
            if let viewModels, !viewModels.isEmpty {
                viewModels.count
            } else {
                1 // The placeholder cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .summary:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_positions_value, for: indexPath)!
            switch content {
            case .open:
                cell.loadOpenPositions(value: value)
            case .closed:
                cell.loadClosedPositions(value: value)
            }
            return cell
        case .positions:
            if let viewModels, !viewModels.isEmpty {
                let viewModel = viewModels[indexPath.item]
                switch content {
                case .open:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                    cell.load(viewModel: viewModel)
                    return cell
                case .closed:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_inactive_position, for: indexPath)!
                    cell.load(viewModel: viewModel)
                    return cell
                }
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_placeholder, for: indexPath)!
                if viewModels == nil {
                    cell.activityIndicatorView.startAnimating()
                    cell.emptyIndicatorStackView.isHidden = true
                } else {
                    cell.activityIndicatorView.stopAnimating()
                    cell.emptyIndicatorStackView.isHidden = false
                    cell.titleLabel.text = switch content {
                    case .open:
                        R.string.localizable.no_position().uppercased()
                    case .closed:
                        R.string.localizable.no_activity().uppercased()
                    }
                }
                cell.helpButton.isHidden = content == .closed
                cell.onHelp = { [weak self] in
                    let manual = PerpsManual.viewController()
                    self?.present(manual, animated: true)
                }
                return cell
            }
        }
    }
    
}

extension AllPerpetualPositionsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath {
            loadNextPageIndexPath = nil
            if let offset = viewModels?.last?.closedAt {
                loadNextPage(offset: offset)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .summary:
            break
        case .positions:
            guard let viewModels, !viewModels.isEmpty else {
                return
            }
            let viewModel = viewModels[indexPath.item]
            switch content {
            case .open:
                if let market = PerpsMarketDAO.shared.market(marketID: viewModel.marketID),
                   let viewModel = PerpetualMarketViewModel(market: market)
                {
                    let market = PerpetualMarketViewController(
                        wallet: wallet,
                        viewModel: viewModel,
                    )
                    navigationController?.pushViewController(market, animated: true)
                }
            case .closed:
                let controller = PerpetualPositionViewController(wallet: wallet, viewModel: viewModel)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
    
}
