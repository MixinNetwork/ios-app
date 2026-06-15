import UIKit
import MixinServices

final class MixinTokensViewController: TokensViewController {
    
    private var overview: WalletOverview?
    private var overviewTray: WalletOverview.Tray?
    private var tokens: [MixinTokenItem]?
    
    private var isDisplayingSearch = false
    private var searchTokenHandler: WalletSearchMixinTokenHandler?
    private var overviewActionHandler: PrivacyWalletOverviewActionHandler?
    private var pendingDepositObserver: PrivacyWalletPendingDepositObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.wallet_home_tokens(),
            wallet: .privacy
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: R.image.ic_title_more(),
                style: .plain,
                target: self,
                action: #selector(presentMoreMenu(_:))
            ),
            UIBarButtonItem(
                image: R.image.ic_title_search(),
                style: .plain,
                target: self,
                action: #selector(presentSearch(_:))
            ),
        ]
        collectionView.dataSource = self
        collectionView.delegate = self
        
        overviewActionHandler = PrivacyWalletOverviewActionHandler(
            tradeSource: .tokenList,
            responder: self
        )
        let pendingDepositObserver = PrivacyWalletPendingDepositObserver()
        pendingDepositObserver.delegate = self
        pendingDepositObserver.reloadPendingDeposits()
        self.pendingDepositObserver = pendingDepositObserver
        
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: ChainDAO.chainsDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: UTXOService.balanceDidUpdateNotification,
            object: nil
        )
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pendingDepositObserver?.reloadPendingDeposits()
    }
    
    override func hideTokenAction(indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.hide()
        ) { [weak self] (action, _, completionHandler) in
            guard
                let self,
                let token = self.tokens?[indexPath.item]
            else {
                return
            }
            let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(token.symbol), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.hide(), style: .default, handler: { (_) in
                self.hide(token: token)
            }))
            self.present(alert, animated: true, completion: nil)
            completionHandler(true)
        }
        action.backgroundColor = R.color.theme()
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokensValue = TokenDAO.shared.usdBalanceSum(includesHiddenTokens: false)
            let btcPrice = TokenDAO.shared.usdPrice(assetID: AssetID.btc)
            let overview = WalletOverview(
                tokensValue: tokensValue,
                perpsValue: 0,
                btcPrice: btcPrice
            )
            let tokens = TokenDAO.shared.notHiddenTokens(
                includesZeroBalanceItems: true,
                limit: nil
            )
            var sections: [Section] = [.overview]
            if tokens.isEmpty {
                sections.append(.emptyIndicator)
            } else {
                sections.append(.tokens)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.sections = sections
                self.overview = overview
                self.tokens = tokens
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc private func presentSearch(_ sender: Any) {
        let modelController = WalletSearchMixinTokenController()
        let searchTokenHandler = WalletSearchMixinTokenHandler(
            navigationController: navigationController
        )
        modelController.delegate = searchTokenHandler
        let search = WalletSearchViewController(modelController: modelController)
        self.searchTokenHandler = searchTokenHandler
        self.isDisplayingSearch = true
        search.onWillDismiss = { [weak self] in
            self?.isDisplayingSearch = false
        }
        search.presentAsChild(on: self)
    }
    
    @objc private func presentMoreMenu(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            let history = MixinTransactionHistoryViewController(type: nil)
            self.navigationController?.pushViewController(history, animated: true)
            reporter.report(event: .allTransactions, tags: ["source": "token_list"])
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            self.navigationController?.pushViewController(HiddenMixinTokensViewController(), animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    private func hide(token: MixinTokenItem) {
        DispatchQueue.global().async { [weak self] in
            reporter.report(event: .hideAsset, tags: ["wallet": "main", "source": "wallet_home"])
            let extra = TokenExtra(
                assetID: token.assetID,
                kernelAssetID: token.kernelAssetID,
                isHidden: true,
                balance: token.balance,
                updatedAt: Date().toUTCString()
            )
            TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            DispatchQueue.main.async {
                self?.reloadData()
            }
        }
    }
    
}

extension MixinTokensViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        isDisplayingSearch ? .hide : .secondaryBackground
    }
    
}

extension MixinTokensViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .overview:
            1
        case .tokens:
            tokens?.count ?? 0
        case .emptyIndicator:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .overview:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_overview, for: indexPath)!
            cell.load(overview: overview)
            cell.load(action: .general)
            cell.load(tray: overviewTray)
            cell.delegate = overviewActionHandler
            return cell
        case .tokens:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.token, for: indexPath)!
            if let token = tokens?[indexPath.item] {
                cell.load(token: token)
            }
            return cell
        case .emptyIndicator:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.no_token_indicator, for: indexPath)!
        }
    }
    
}

extension MixinTokensViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .overview, .emptyIndicator:
            break
        case .tokens:
            guard let token = tokens?[indexPath.item] else {
                return
            }
            let viewController = MixinTokenViewController(token: token)
            navigationController?.pushViewController(viewController, animated: true)
            reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "token_list"])
        }
    }
    
}

extension MixinTokensViewController: PrivacyWalletPendingDepositObserver.Delegate {
    
    func privacyWalletPendingDepositObserver(
        _ observer: PrivacyWalletPendingDepositObserver,
        didUpdateWith tokens: [MixinToken],
        snapshots: [SafeSnapshot]
    ) {
        if snapshots.isEmpty {
            overviewTray = nil
        } else {
            overviewTray = .pendingDeposits(tokens: tokens, snapshots: snapshots)
        }
        if let sectionIndex = sections.firstIndex(of: .overview) {
            collectionView.performBatchUpdates {
                let sections = IndexSet(integer: sectionIndex)
                collectionView.reloadSections(sections)
            }
        }
    }
    
}
