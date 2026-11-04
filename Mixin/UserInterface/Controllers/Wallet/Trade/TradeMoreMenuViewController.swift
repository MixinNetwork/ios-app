import UIKit
import MixinServices

final class TradeMoreMenuViewController: UIViewController {
    
    private enum Item {
        case swapOrders
        case limitOrders
        case perpetualActivity
        case perpsPro
    }
    
    private let wallet: Wallet
    private let sections: [[Item]]
    
    private weak var collectionView: UICollectionView!
    
    private var orderCounts: [Item: Int] = [:]
    
    init(wallet: Wallet) {
        self.wallet = wallet
        self.sections = switch wallet {
        case .privacy:
            [
                [.swapOrders, .limitOrders],
                [.perpetualActivity],
                [.perpsPro],
            ]
        case .common, .safe:
            [
                [.swapOrders, .limitOrders],
            ]
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.standardAppearance = .backgroundSecondaryColored
        navigationItem.scrollEdgeAppearance = .backgroundSecondaryColored
        navigationItem.compactAppearance = .backgroundSecondaryColored
        navigationItem.compactScrollEdgeAppearance = .backgroundSecondaryColored
        let titleView = TradeTitleView(wallet: wallet)
        titleView.alignment = .leading
        let titleItem = UIBarButtonItem(customView: titleView)
        if #available(iOS 26.0, *) {
            titleItem.hidesSharedBackground = true
        }
        navigationItem.leftBarButtonItem = titleItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close(_:))
        )
        view.backgroundColor = R.color.background_secondary()
        
        let layout = UICollectionViewCompositionalLayout { [sections] sectionIndex, environment in
            let section: NSCollectionLayoutSection
            switch sections[sectionIndex].first {
            case .swapOrders, .limitOrders, .perpetualActivity:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(64),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 0, trailing: 16)
            case .perpsPro:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(323),
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 36, leading: 16, bottom: 0, trailing: 16)
            case .none:
                return nil
            }
            let background = NSCollectionLayoutDecorationItem.background(
                elementKind: TradeSectionBackgroundView.CornerRadius.large.rawValue
            )
            background.contentInsets = section.contentInsets
            section.decorationItems = [background]
            return section
        }
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.CornerRadius.large.rawValue
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.alwaysBounceVertical = true
        collectionView.register(R.nib.tradeOrderCategoryCell)
        collectionView.register(R.nib.perpsProCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
        
        DispatchQueue.global().async { [wallet, weak self] in
            let walletID = wallet.tradingWalletID
            let positionsCount: Int
            switch wallet {
            case .privacy:
                positionsCount = PerpsPositionDAO.shared.count()
            case .common, .safe:
                positionsCount = 0
            }
            let counts: [Item: Int] = [
                .swapOrders: Web3OrderDAO.shared.openOrdersCount(walletID: walletID, type: .swap),
                .limitOrders: Web3OrderDAO.shared.openOrdersCount(walletID: walletID, type: .limit),
                .perpetualActivity: positionsCount,
            ]
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                orderCounts = counts
                collectionView.reloadData()
            }
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

extension TradeMoreMenuViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = sections[indexPath.section][indexPath.item]
        let title: String
        switch item {
        case .swapOrders:
            title = R.string.localizable.trade_swap_orders()
        case .limitOrders:
            title = R.string.localizable.trade_limit_orders()
        case .perpetualActivity:
            title = R.string.localizable.trade_perpetual_activity()
        case .perpsPro:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.perps_pro,
                for: indexPath
            )!
            cell.delegate = self
            return cell
        }
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: R.reuseIdentifier.trade_order_category,
            for: indexPath
        )!
        cell.titleLabel.text = title
        cell.countLabel.text = orderCounts[item]?.formatted()
        return cell
    }
    
}

extension TradeMoreMenuViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let next: UIViewController
        switch sections[indexPath.section][indexPath.item] {
        case .swapOrders:
            next = TradeOrdersViewController(wallet: wallet, type: .swap, status: nil)
        case .limitOrders:
            next = TradeOrdersViewController(wallet: wallet, type: .limit, status: nil)
        case .perpetualActivity:
            next = PerpetualPositionsViewController(wallet: wallet)
        case .perpsPro:
            return
        }
        presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.homeNavigationController?.pushViewController(next, animated: true)
        }
    }
    
}

extension TradeMoreMenuViewController: PerpsProCell.Delegate {
    
    func perpsProCellDidSelectEnter(_ cell: PerpsProCell) {
        presentingViewController?.dismiss(animated: true) {
            _ = UrlWindow.checkUrl(url: .perpsPro)
            reporter.report(
                event: .tradeProClick,
                tags: ["source": "trade_more_menu"]
            )
        }
    }
    
}
