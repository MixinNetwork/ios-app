import UIKit
import MixinServices

final class AllPerpetualPositionsContentViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case summary
        case positions
    }
    
    private let wallet: Wallet
    private let content: PerpetualPositionType
    private let pageCount = 50
    
    private weak var collectionView: UICollectionView!
    
    private var viewModels: [PerpetualPositionViewModel] = []
    private var loadNextPageIndexPath: IndexPath?
    
    init(wallet: Wallet, content: PerpetualPositionType) {
        self.wallet = wallet
        self.content = content
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
            sectionProvider: { [weak self] (sectionIndex, _) in
                switch Section.allCases[sectionIndex] {
                case .summary:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(38))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .positions:
                    let itemSize = if let self, !self.viewModels.isEmpty {
                        NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(50))
                    } else {
                        NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(150))
                    }
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                    section.interGroupSpacing = 20
                    let background: NSCollectionLayoutDecorationItem = .background(
                        elementKind: TradeSectionBackgroundView.elementKind
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    section.decorationItems = [background]
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
        collectionView.register(R.nib.perpetualClosedPositionCell)
        collectionView.register(R.nib.perpetualPlaceholderCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        switch content {
        case .open:
            DispatchQueue.global().async { [wallet, weak self] in
                let viewModels = PerpsPositionDAO.shared.positionItems().map { item in
                    PerpetualPositionViewModel(wallet: wallet, position: item)
                }
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.viewModels = viewModels
                    self.collectionView.reloadData()
                }
            }
        case .closed:
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
            let hasMore = viewModels.count < pageCount
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if self.viewModels.isEmpty {
                    self.viewModels = viewModels
                    self.collectionView.reloadData()
                } else {
                    let itemsCountBefore = self.viewModels.count
                    self.viewModels.append(contentsOf: viewModels)
                    let itemsCountAfter = self.viewModels.count
                    self.collectionView.performBatchUpdates {
                        let summary = IndexSet(integer: Section.summary.rawValue)
                        self.collectionView.reloadSections(summary)
                        let items = (itemsCountBefore..<itemsCountAfter).map { item in
                            IndexPath(item: item, section: Section.positions.rawValue)
                        }
                        self.collectionView.insertItems(at: items)
                    }
                }
                if hasMore {
                    self.loadNextPageIndexPath = IndexPath(
                        item: self.viewModels.count - 3,
                        section: Section.positions.rawValue
                    )
                }
            }
        }
    }
    
}

extension AllPerpetualPositionsContentViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            1
        } else {
            max(1, viewModels.count)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .summary:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_positions_value, for: indexPath)!
            return cell
        case .positions:
            if viewModels.isEmpty {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_placeholder, for: indexPath)!
                cell.activityIndicatorView.stopAnimating()
                cell.helpButton.isHidden = true
                return cell
            } else {
                let viewModel = viewModels[indexPath.item]
                switch content {
                case .open:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
                    cell.load(viewModel: viewModel)
                    return cell
                case .closed:
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_closed_position, for: indexPath)!
                    cell.load(viewModel: viewModel)
                    return cell
                }
            }
        }
    }
    
}

extension AllPerpetualPositionsContentViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath {
            loadNextPageIndexPath = nil
            if let offset = viewModels.last?.closedAt {
                loadNextPage(offset: offset)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .summary:
            break
        case .positions:
            let viewModel = viewModels[indexPath.item]
            let controller = PerpetualPositionViewController(viewModel: viewModel)
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
}
