import UIKit
import MixinServices

final class PerpetualActivityViewController: UIViewController {
    
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
    private let viewModel: PerpetualActivityViewModel
    private let infos: [Info]
    
    init(wallet: Wallet, viewModel: PerpetualActivityViewModel) {
        var infos: [Info] = []
        if let displaySymbol = viewModel.displaySymbol {
            infos.append(.product(iconURL: viewModel.iconURL, name: displaySymbol))
        }
        switch viewModel.status {
        case .normal:
            switch viewModel.type {
            case .open, .increase:
                infos.append(.general(
                    title: R.string.localizable.entry_price().uppercased(),
                    content: viewModel.entryPrice
                ))
            case .close(let pnl, let closePrice):
                infos.append(contentsOf: [
                    .pnl(value: pnl.precised, color: pnl.color),
                    .general(
                        title: R.string.localizable.entry_price().uppercased(),
                        content: viewModel.entryPrice
                    ),
                    .general(
                        title: R.string.localizable.close_price().uppercased(),
                        content: closePrice
                    ),
                ])
            }
        case .rejected:
            break
        }
        infos.append(contentsOf: [
            .wallet(.privacy),
            .general(title: R.string.localizable.date().uppercased(), content: viewModel.date),
        ])
        
        self.wallet = wallet
        self.viewModel = viewModel
        self.infos = infos
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
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

extension PerpetualActivityViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension PerpetualActivityViewController: UICollectionViewDataSource {
    
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

extension PerpetualActivityViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        switch viewModel.actions[index] {
        case .viewMarket, .tradeAgain:
            if let market = PerpsMarketDAO.shared.market(marketID: viewModel.marketID),
               let viewModel = PerpetualMarketViewModel(market: market),
               let navigationController
            {
                let market = PerpetualMarketViewController(
                    wallet: wallet,
                    viewModel: viewModel,
                )
                var viewControllers = navigationController.viewControllers
                viewControllers.removeAll { controller in
                    controller is PerpetualMarketViewController
                    || controller is PerpetualPositionsViewController
                    || controller is PerpetualActivitiesViewController
                    || controller is PerpetualActivityViewController
                }
                viewControllers.append(market)
                navigationController.setViewControllers(viewControllers, animated: true)
            }
        case .share:
            let dataSource: SharePerpetualPositionDataSource
            switch viewModel.type {
            case .open, .increase:
                if let order = PerpsOrderDAO.shared.closeOrderItem(positionID: viewModel.positionID),
                   let viewModel = PerpetualActivityViewModel(wallet: wallet, order: order)
                {
                    switch viewModel.type {
                    case .open, .increase:
                        return
                    case .close(let pnl, let closePrice):
                        dataSource = SharePerpetualPositionDataSource(
                            viewModel: viewModel,
                            pnl: pnl,
                            closePrice: closePrice
                        )
                    }
                } else if let position = PerpsPositionDAO.shared.position(marketID: viewModel.marketID) {
                    let viewModel = PerpetualPositionViewModel(wallet: wallet, position: position)
                    let latestPrice: Decimal? = {
                        if let price = PerpsMarketDAO.shared.price(marketID: viewModel.marketID) {
                            Decimal(string: price, locale: .enUSPOSIX)
                        } else {
                            nil
                        }
                    }()
                    dataSource = SharePerpetualPositionDataSource(
                        viewModel: viewModel,
                        latestPrice: latestPrice
                    )
                } else {
                    return
                }
            case .close(let pnl, let closePrice):
                dataSource = SharePerpetualPositionDataSource(
                    viewModel: viewModel,
                    pnl: pnl,
                    closePrice: closePrice
                )
            }
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            Referral.loadAvailableCode { [weak self] code in
                hud.hide()
                let share = SharePerpetualPositionViewController(dataSource: dataSource, rebatingCode: code)
                self?.present(share, animated: true)
            }
        }
    }
    
}
