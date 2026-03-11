import UIKit
import MixinServices

final class PerpetualPositionViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case header
        case info
    }
    
    enum Info {
        case product(iconURL: URL?, name: String)
        case orderValue(token: String, fiatMoney: String)
        case general(title: String, content: String)
        case pnl(value: String, color: MarketColor)
        case wallet(Wallet)
    }
    
    private let wallet: Wallet
    private let viewModel: PerpetualPositionViewModel
    private let infos: [Info]
    
    init(wallet: Wallet, viewModel: PerpetualPositionViewModel) {
        self.wallet = wallet
        self.viewModel = viewModel
        
        var infos: [Info] = []
        if let displaySymbol = viewModel.displaySymbol {
            infos.append(.product(iconURL: viewModel.iconURL, name: displaySymbol))
        }
        infos.append(contentsOf: [
            .pnl(value: viewModel.pnl, color: viewModel.pnlColor),
            .general(
                title: R.string.localizable.entry_price().uppercased(),
                content: viewModel.entryPrice
            ),
        ])
        if let closePrice = viewModel.closePrice {
            infos.append(.general(
                title: R.string.localizable.close_price().uppercased(),
                content: closePrice
            ))
        }
        infos.append(contentsOf: [
            .wallet(.privacy),
            .general(title: R.string.localizable.date().uppercased(), content: viewModel.date),
        ])
        self.infos = infos
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = switch (viewModel.state, viewModel.side) {
        case (.open, .long):
            R.string.localizable.opened_long()
        case (.open, .short):
            R.string.localizable.opened_short()
        case (.closed, .long):
            R.string.localizable.closed_long()
        case (.closed, .short):
            R.string.localizable.closed_short()
        }
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, _ in
            switch Section(rawValue: sectionIndex)! {
            case .header:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(275)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            case .info:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(40)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 20
                section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
                let background: NSCollectionLayoutDecorationItem = .background(
                    elementKind: TradeSectionBackgroundView.elementKind
                )
                background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                section.decorationItems = [background]
                return section
            }
        }, configuration: config)
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind
        )
        
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        collectionView.register(R.nib.perpetualPositionHeaderCell)
        collectionView.register(R.nib.perpetualPositionProductCell)
        collectionView.register(R.nib.perpetualPositionWalletCell)
        collectionView.register(R.nib.perpetualPositionInfoCell)
        collectionView.register(R.nib.perpetualPositionCompactInfoCell)
        collectionView.allowsSelection = false
        collectionView.dataSource = self
        collectionView.reloadData()
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "perps_position"])
    }
    
}

extension PerpetualPositionViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension PerpetualPositionViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .header:
            1
        case .info:
            infos.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .header:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_header, for: indexPath)!
            cell.load(viewModel: viewModel)
            cell.actionView.delegate = self
            return cell
        case .info:
            switch infos[indexPath.item] {
            case let .product(iconURL, name):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_product, for: indexPath)!
                cell.iconView.setIcon(tokenIconURL: iconURL)
                cell.nameLabel.text = name
                return cell
            case let .orderValue(token, fiatMoney):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_info, for: indexPath)!
                cell.titleLabel.text = R.string.localizable.position_size().uppercased()
                cell.primaryLabel.text = token
                cell.secondaryLabel.text = fiatMoney
                return cell
            case let .general(title, content):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_compact_info, for: indexPath)!
                cell.titleLabel.text = title
                cell.contentLabel.text = content
                cell.contentLabel.textColor = R.color.text()
                return cell
            case let .pnl(value, color):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_compact_info, for: indexPath)!
                cell.titleLabel.text = R.string.localizable.pnl()
                cell.contentLabel.text = value
                cell.contentLabel.marketColor = color
                return cell
            case let .wallet(wallet):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_position_wallet, for: indexPath)!
                cell.titleLabel.text = R.string.localizable.wallet().uppercased()
                switch wallet {
                case .privacy:
                    cell.nameLabel.text = R.string.localizable.privacy_wallet()
                    cell.iconImageView.isHidden = false
                case .common(let wallet):
                    cell.nameLabel.text = wallet.name
                    cell.iconImageView.isHidden = true
                case .safe(let wallet):
                    cell.nameLabel.text = wallet.name
                    cell.iconImageView.isHidden = true
                }
                return cell
            }
        }
    }
    
}

extension PerpetualPositionViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        switch viewModel.actions[index] {
        case .tradeAgain:
            if let market = PerpsMarketDAO.shared.market(marketID: viewModel.marketID),
               let viewModel = PerpetualMarketViewModel(market: market),
               let navigationController
            {
                let market = PerpetualMarketViewController(wallet: wallet, viewModel: viewModel)
                var viewControllers = navigationController.viewControllers
                viewControllers.removeAll { controller in
                    controller is PerpetualMarketViewController
                    || controller is PerpetualPositionViewController
                    || controller is AllPerpetualPositionsViewController
                }
                viewControllers.append(market)
                navigationController.setViewControllers(viewControllers, animated: true)
            }
        case .close:
            let preview = ClosePerpetualPositionPreviewViewController(viewModel: viewModel)
            present(preview, animated: true)
        case .share:
            let share = SharePerpetualPositionViewController(viewModel: viewModel)
            present(share, animated: true)
        }
    }
    
}
