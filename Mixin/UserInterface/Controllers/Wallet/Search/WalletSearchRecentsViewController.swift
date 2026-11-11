import UIKit
import MixinServices

final class WalletSearchRecentsViewController<ModelController: WalletSearchModelController>: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    private(set) weak var collectionView: UICollectionView!
    
    private let modelController: ModelController
    private let queue = DispatchQueue(label: "one.mixin.messenger.WalletRecentSearches")
    
    private var items: [WalletSearchItem<ModelController.Item>] = []
    
    init(modelController: ModelController) {
        self.modelController = modelController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        let size = NSCollectionLayoutSize(
            widthDimension: .estimated(159),
            heightDimension: .estimated(41),
        )
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(41),
            ),
            subitems: [item],
        )
        group.interItemSpacing = .fixed(16)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20)
        section.supplementariesFollowContentInsets = false
        section.interGroupSpacing = 12
        section.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(56)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top,
        )]
        let collectionView = UICollectionView(
            frame: view.bounds,
            collectionViewLayout: UICollectionViewCompositionalLayout(section: section),
        )
        collectionView.backgroundColor = .background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
        collectionView.register(R.nib.walletSearchRecentCell)
        collectionView.register(R.nib.recentSearchHeaderView, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader)
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recentSearchesDidChange(_:)),
            name: PropertiesDAO.propertyDidUpdateNotification,
            object: nil,
        )
        reloadData()
    }
    
    @objc func recentSearchesDidChange(_ notification: Notification) {
        guard notification.userInfo?[PropertiesDAO.Key.walletRecentSearches] != nil else {
            return
        }
        reloadData()
    }
    
    @objc private func reloadData() {
        queue.async { [weak self, modelController] in
            let items = modelController.recentItems()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                UIView.performWithoutAnimation {
                    self.items = items
                    self.collectionView.reloadData()
                    self.view.layoutIfNeeded()
                    self.collectionView.layoutIfNeeded()
                }
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource & UICollectionViewDelegate
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        items.isEmpty ? 0 : 1
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int,
    ) -> Int {
        items.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath,
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_search_recent, for: indexPath)!
        cell.iconView.prepareForReuse()
        switch items[indexPath.item] {
        case .token(let token):
            cell.layout(iconSize: .medium)
            if let mixinToken = token as? MixinTokenItem {
                cell.iconView.setIcon(token: mixinToken)
            } else {
                cell.iconView.setIcon(token: token, chain: token.chain)
            }
            cell.titleLabel.text = token.name
            cell.subtitleLabel.text = token.localizedBalanceWithSymbol
        case let .perps(position, market):
            cell.layout(iconSize: .medium)
            cell.iconView.setIcon(market: market)
            cell.titleLabel.text = position.displaySymbol ?? position.tokenSymbol
            let direction = if position.side == PerpetualOrderSide.long.rawValue {
                R.string.localizable.long_asset(position.tokenSymbol)
            } else {
                R.string.localizable.short_asset(position.tokenSymbol)
            }
            cell.subtitleLabel.text = direction + " · " + PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
        case .earn(let viewModel):
            cell.layout(iconSize: .medium)
            cell.iconView.setIcon(token: viewModel.token)
            cell.titleLabel.text = viewModel.symbol
            cell.subtitleLabel.text = viewModel.value
            cell.apyLabel.text = viewModel.apy
            cell.apyLabel.isHidden = viewModel.apy == nil
        case .collectible(let output):
            cell.layout(iconSize: .small)
            if let inscription = output.inscription {
                cell.iconView.setIcon(content: inscription, cornerRadius: 8)
            }
            cell.titleLabel.text = output.inscription?.collectionName ?? R.string.localizable.collectibles()
            cell.subtitleLabel.text = output.inscription?.sequenceRepresentation ?? output.inscriptionHash
        }
        cell.accessibilityLabel = [
            cell.titleLabel.text,
            cell.apyLabel.isHidden ? nil : cell.apyLabel.text,
            cell.subtitleLabel.text,
        ].compactMap { $0 }.joined(separator: ", ")
        return cell
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: R.reuseIdentifier.recent_search_header,
            for: indexPath,
        )!
        header.delegate = self
        return header
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath,
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.item]
        if let recentSearch = item.recentSearch() {
            modelController.insertRecentSearch(recentSearch)
        }
        parent?.view.endEditing(true)
        switch item {
        case .token(let token):
            modelController.reportUserSelection(token: token)
        case let .perps(_, market):
            let controller = PerpetualMarketViewController(
                wallet: .privacy,
                viewModel: PerpetualMarketViewModel(market: market),
            )
            navigationController?.pushViewController(controller, animated: true)
        case .earn(let viewModel):
            UIApplication.shared.homeNavigationController?.presentEarnPage(
                additionalURLQueries: ["production": viewModel.productionID]
            )
        case .collectible(let output):
            navigationController?.pushViewController(
                InscriptionViewController(output: output),
                animated: true,
            )
        }
    }
    
}

extension WalletSearchRecentsViewController: RecentSearchHeaderView.Delegate {
    
    func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView) {
        items = []
        collectionView.reloadData()
        PropertiesDAO.shared.removeValue(forKey: .walletRecentSearches)
    }
    
}
