import UIKit
import MixinServices

final class TradeViewController: UIViewController {
    
    enum Trading: Int, CaseIterable {
        case simpleSpot
        case advancedSpot
        case perpetualFutures
    }
    
    struct Context {
        let sendAssetID: String?
        let receiveAssetID: String?
        let referral: String?
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var containerView: UIView!
    
    private let allTradings: [Trading] = [.simpleSpot, .advancedSpot, .perpetualFutures]
    private let wallet: Wallet
    private let supportedChainIDs: Set<String>? // nil for all
    private let initialContext: Context
    
    private var trading: Trading
    private var tradingViewController: UIViewController?
    
    private weak var showOrdersItem: BadgeBarButtonItem?
    
    init?(
        wallet: Wallet,
        supportedChainIDs: Set<String>? = nil, // nil for all
        trading: Trading?,
        sendAssetID: String?,
        receiveAssetID: String?,
        referral: String?,
    ) {
        switch wallet {
        case .safe, 
                .common where trading == .perpetualFutures:
            assertionFailure("Unsupported combination")
            return nil
        default:
            break
        }
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        self.trading = trading
        ?? Trading(rawValue: AppGroupUserDefaults.Wallet.tradeMode)
        ?? .simpleSpot
        self.initialContext = Context(
            sendAssetID: sendAssetID,
            receiveAssetID: receiveAssetID,
            referral: referral
        )
        let nib = R.nib.tradeView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let showOrdersItem = BadgeBarButtonItem(
            image: R.image.ic_title_transaction()!,
            target: self,
            action: #selector(showOrders(_:))
        )
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.trade(),
            wallet: wallet
        )
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            ),
            showOrdersItem,
        ]
        self.showOrdersItem = showOrdersItem
        
        collectionView.register(R.nib.exploreSegmentCell)
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = UICollectionViewFlowLayout.automaticSize
            layout.estimatedItemSize = CGSize(width: 100, height: 38)
            layout.minimumInteritemSpacing = 0
        }
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        let defaultSelection = if let item = allTradings.firstIndex(of: trading) {
            IndexPath(item: item, section: 0)
        } else {
            IndexPath(item: 0, section: 0)
        }
        collectionView.selectItem(at: defaultSelection, animated: false, scrollPosition: .left)
        replaceChildViewController(trading: trading)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateOrdersButton),
            name: Web3OrderDAO.didSaveNotification,
            object: nil
        )
        updateOrdersButton()
    }
    
    func prepareForReuse() {
        
    }
    
    func switchTo(trading: Trading) {
        guard trading != self.trading else {
            return
        }
        self.trading = trading
        replaceChildViewController(trading: trading)
    }
    
    @objc func showOrders(_ sender: Any) {
        BadgeManager.shared.setHasViewed(identifier: .tradeOrder)
        if let showOrdersItem, showOrdersItem.compatibleBadge == .unread {
            showOrdersItem.compatibleBadge = nil
        }
        switch trading {
        case .simpleSpot, .advancedSpot:
            let showPendingOrdersOnly = sender is TradeSectionHeaderView || sender is TradeViewAllFooterView
            let orders = TradeOrdersViewController(
                wallet: wallet,
                status: showPendingOrdersOnly ? .pending : nil
            )
            navigationController?.pushViewController(orders, animated: true)
        case .perpetualFutures:
            break
        }
    }
    
    @objc func updateOrdersButton() {
        assert(Thread.isMainThread)
        let walletID = (tradingViewController as? TradeSpotViewController)?.orderWalletID
        guard let showOrdersItem, let walletID else {
            return
        }
        let swapOrdersUnread = !BadgeManager.shared.hasViewed(identifier: .tradeOrder)
        DispatchQueue.global().async { [weak showOrdersItem] in
            let openOrdersCount = min(
                99,
                Web3OrderDAO.shared.openOrdersCount(walletID: walletID)
            )
            let badge: BadgeBarButtonView.Badge? = if openOrdersCount != 0 {
                .count(openOrdersCount)
            } else if swapOrdersUnread {
                .unread
            } else {
                nil
            }
            DispatchQueue.main.async {
                showOrdersItem?.compatibleBadge = badge
            }
        }
    }
    
    @objc func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_home"])
    }
    
    private func replaceChildViewController(trading: Trading) {
        var context: Context?
        if let tradingViewController {
            tradingViewController.willMove(toParent: nil)
            tradingViewController.view.removeFromSuperview()
            tradingViewController.removeFromParent()
            if let trading = tradingViewController as? TradeSpotViewController {
                context = Context(
                    sendAssetID: trading.sendToken?.assetID,
                    receiveAssetID: trading.receiveToken?.assetID,
                    referral: initialContext.referral
                )
            }
        }
        
        let tradingViewController: UIViewController
        switch wallet {
        case .safe:
            assertionFailure("Unsupported combination")
            return
        case .privacy:
            switch trading {
            case .simpleSpot:
                tradingViewController = TradeMixinSpotViewController(
                    mode: .simple,
                    sendAssetID: context?.sendAssetID,
                    receiveAssetID: context?.receiveAssetID,
                    referral: context?.referral
                )
            case .advancedSpot:
                tradingViewController = TradeMixinSpotViewController(
                    mode: .advanced,
                    sendAssetID: context?.sendAssetID,
                    receiveAssetID: context?.receiveAssetID,
                    referral: context?.referral
                )
            case .perpetualFutures:
                tradingViewController = TradePerpetualViewController(
                    wallet: .privacy
                )
            }
        case .common(let wallet):
            switch trading {
            case .simpleSpot:
                tradingViewController = TradeWeb3SpotViewController(
                    wallet: wallet,
                    mode: .simple,
                    supportedChainIDs: supportedChainIDs,
                    sendAssetID: context?.sendAssetID,
                    receiveAssetID: context?.receiveAssetID,
                )
            case .advancedSpot:
                tradingViewController = TradeWeb3SpotViewController(
                    wallet: wallet,
                    mode: .advanced,
                    supportedChainIDs: supportedChainIDs,
                    sendAssetID: context?.sendAssetID,
                    receiveAssetID: context?.receiveAssetID,
                )
            case .perpetualFutures:
                assertionFailure("Unsupported combination")
                return
            }
        }
        self.tradingViewController = tradingViewController
        
        addChild(tradingViewController)
        containerView.insertSubview(tradingViewController.view, at: 0)
        tradingViewController.view.snp.makeEdgesEqualToSuperview()
        tradingViewController.didMove(toParent: self)
    }
    
}

extension TradeViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension TradeViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allTradings.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        switch allTradings[indexPath.item] {
        case .simpleSpot:
            cell.label.text = R.string.localizable.trade_simple()
            cell.badgeView.isHidden = true
        case .advancedSpot:
            cell.label.text = R.string.localizable.trade_advanced()
            cell.badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .advancedTrade)
        case .perpetualFutures:
            cell.label.text = "Perpetual"
            cell.badgeView.isHidden = BadgeManager.shared.hasViewed(identifier: .perps)
        }
        return cell
    }
    
}

extension TradeViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let trading = allTradings[indexPath.item]
        switch trading {
        case .simpleSpot:
            break
        case .advancedSpot:
            BadgeManager.shared.setHasViewed(identifier: .advancedTrade)
        case .perpetualFutures:
            BadgeManager.shared.setHasViewed(identifier: .perps)
        }
        if let cell = collectionView.cellForItem(at: indexPath) as? ExploreSegmentCell {
            cell.badgeView.isHidden = true
        }
        AppGroupUserDefaults.Wallet.tradeMode = trading.rawValue
        switchTo(trading: trading)
    }
    
}

extension TradeViewController {
    
}
