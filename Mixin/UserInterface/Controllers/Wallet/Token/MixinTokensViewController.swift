import UIKit
import MixinServices

final class MixinTokensViewController: TokensViewController {
    
    private var overview: WalletOverview?
    private var overviewTray: WalletOverview.Tray?
    private var tokens: [MixinTokenItem]?
    
    private var overviewActionHandler: PrivacyWalletOverviewActionHandler?
    private var pendingDepositObserver: PrivacyWalletPendingDepositObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.wallet_home_tokens(),
            wallet: .privacy
        )
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
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let overview = {
                let usdValue = TokenDAO.shared.usdBalanceSum(includesHiddenTokens: false)
                let btcPrice: Decimal?
                if let price = TokenDAO.shared.usdPrice(assetID: AssetID.btc) {
                    btcPrice = Decimal(string: price, locale: .enUSPOSIX)
                } else {
                    btcPrice = nil
                }
                return WalletOverview(usdValue: usdValue, btcPrice: btcPrice)
            }()
            let tokens = TokenDAO.shared.notHiddenTokens(
                includesZeroBalanceItems: true,
                limit: nil
            )
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.overview = overview
                self.tokens = tokens
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension MixinTokensViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .overview:
            1
        case .tokens:
            tokens?.count ?? 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
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
        }
    }
    
}

extension MixinTokensViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let token = tokens?[indexPath.item] else {
            return
        }
        let viewController = MixinTokenViewController(token: token)
        navigationController?.pushViewController(viewController, animated: true)
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "token_list"])
    }
    
}

extension MixinTokensViewController: PrivacyWalletPendingDepositObserver.Delegate {
    
    func privacyWalletPendingDepositObserver(
        _ observer: PrivacyWalletPendingDepositObserver,
        didUpdateWith tokens: [MixinToken],
        snapshots: [SafeSnapshot]
    ) {
        overviewTray = .pendingDeposits(tokens: tokens, snapshots: snapshots)
        let overviewIndexPath = IndexPath(item: 0, section: Section.overview.rawValue)
        if let cell = collectionView.cellForItem(at: overviewIndexPath) as? WalletOverviewCell {
            cell.load(tray: overviewTray)
        }
    }
    
}
