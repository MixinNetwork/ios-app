import UIKit
import MixinServices

final class AllPerpetualMarketsViewController: UIViewController {
    
    private let wallet: Wallet
    private let viewModels: [PerpetualMarketViewModel]
    
    init(wallet: Wallet, viewModels: [PerpetualMarketViewModel]) {
        self.wallet = wallet
        self.viewModels = viewModels
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.perps_markets()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(50)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        section.interGroupSpacing = 20
        let background: NSCollectionLayoutDecorationItem = .background(
            elementKind: TradeSectionBackgroundView.elementKind
        )
        background.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.decorationItems = [background]
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 10
        let layout = UICollectionViewCompositionalLayout(section: section, configuration: config)
        layout.register(
            TradeSectionBackgroundView.self,
            forDecorationViewOfKind: TradeSectionBackgroundView.elementKind
        )
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.register(R.nib.perpetualMarketCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "perps_all_markets"])
    }
    
}

extension AllPerpetualMarketsViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AllPerpetualMarketsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModels.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.perps_market, for: indexPath)!
        cell.load(viewModel: viewModels[indexPath.item])
        return cell
    }
    
}

extension AllPerpetualMarketsViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let viewModel = viewModels[indexPath.item]
        let market = PerpetualMarketViewController(
            wallet: wallet,
            viewModel: viewModel,
            alwaysAutoRefreshOpenPosition: false
        )
        navigationController?.pushViewController(market, animated: true)
    }
    
}
