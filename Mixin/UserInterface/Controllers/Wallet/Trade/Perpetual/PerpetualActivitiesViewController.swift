import UIKit
import MixinServices

final class PerpetualActivitiesViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case value
        case activities
    }
    
    private let wallet: Wallet
    private let positionsLoader: PerpetualPositionLoader
    private let pageCount = 50
    
    private weak var collectionView: UICollectionView!
    
    private var value: PerpetualPositionValue?
    private var viewModels: [PerpetualActivityViewModel]?
    private var loadNextPageIndexPath: IndexPath?
    
    init(wallet: Wallet) {
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
        title = R.string.localizable.perps_activity()
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] (sectionIndex, _) in
                switch Section(rawValue: sectionIndex)! {
                case .value:
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(97))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    return section
                case .activities:
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
        collectionView.register(R.nib.perpetualActivityCell)
        collectionView.register(R.nib.perpetualPlaceholderCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: PerpsOrderDAO.perpsOrdersDidSaveNotification,
            object: nil
        )
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
        DispatchQueue.global().async {
            let value = PerpsOrderDAO.shared.activitiesValue()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.value = value
                UIView.performWithoutAnimation {
                    self.collectionView.reloadSections(
                        IndexSet(integer: Section.value.rawValue)
                    )
                }
            }
        }
        loadNextPageIndexPath = nil
        loadNextPage(offset: nil)
    }
    
    private func loadNextPage(offset: String?) {
        DispatchQueue.global().async { [wallet, pageCount, weak self] in
            let orderItems = PerpsOrderDAO.shared.orderItems(
                offsetUpdatedAt: offset,
                limit: pageCount
            )
            let viewModels = orderItems.compactMap { item in
                PerpetualActivityViewModel(wallet: wallet, order: item)
            }
            let hasMore = orderItems.count == pageCount
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
                    UIView.performWithoutAnimation {
                        self.collectionView.reloadSections(
                            IndexSet(integer: Section.activities.rawValue)
                        )
                    }
                } else {
                    let itemsAfter = itemsBefore + viewModels
                    let itemsCountAfter = itemsAfter.count
                    self.viewModels = itemsAfter
                    let items = (itemsCountBefore..<itemsCountAfter).map { item in
                        IndexPath(item: item, section: Section.activities.rawValue)
                    }
                    UIView.performWithoutAnimation {
                        self.collectionView.insertItems(at: items)
                    }
                }
                if hasMore, let count = self.viewModels?.count {
                    self.loadNextPageIndexPath = IndexPath(
                        item: count - 3,
                        section: Section.activities.rawValue
                    )
                }
            }
        }
    }
    
}

extension PerpetualActivitiesViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension PerpetualActivitiesViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .value:
            1
        case .activities:
            if let viewModels, !viewModels.isEmpty {
                viewModels.count
            } else {
                1 // The placeholder cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .value:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_positions_value, for: indexPath)!
            cell.loadClosedActivities(value: value)
            return cell
        case .activities:
            if let viewModels, !viewModels.isEmpty {
                let viewModel = viewModels[indexPath.item]
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_activity, for: indexPath)!
                cell.load(viewModel: viewModel)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_placeholder, for: indexPath)!
                if viewModels == nil {
                    cell.activityIndicatorView.startAnimating()
                    cell.emptyIndicatorStackView.isHidden = true
                } else {
                    cell.activityIndicatorView.stopAnimating()
                    cell.emptyIndicatorStackView.isHidden = false
                    cell.titleLabel.text = R.string.localizable.no_activity().uppercased()
                }
                cell.helpButton.isHidden = true
                return cell
            }
        }
    }
    
}

extension PerpetualActivitiesViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath == loadNextPageIndexPath {
            loadNextPageIndexPath = nil
            if let offset = viewModels?.last?.offset {
                loadNextPage(offset: offset)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .value:
            break
        case .activities:
            guard let viewModels, !viewModels.isEmpty else {
                return
            }
            let viewModel = viewModels[indexPath.item]
            let activity = PerpetualActivityViewController(wallet: wallet, viewModel: viewModel)
            navigationController?.pushViewController(activity, animated: true)
            reporter.report(event: .tradePerpsActivityDetail, tags: ["source": "perps_activity_list"])
        }
    }
    
}
