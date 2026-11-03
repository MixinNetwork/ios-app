import UIKit
import MixinServices

final class TradeViewController: UIViewController {
    
    enum Trading: Int, CaseIterable {
        case simpleSpot
        case advancedSpot
        case perpetualFutures
    }
    
    private struct Context {
        
        let sendAssetID: String?
        let sendAmount: Decimal?
        let receiveAssetID: String?
        let referral: String?
        
        var hasAssetID: Bool {
            sendAssetID != nil || receiveAssetID != nil
        }
        
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var containerView: UIView!
    
    private let allTradings: [Trading]
    private let wallet: Wallet
    private let supportedChainIDs: Set<String>? // nil for all
    private let initialContext: Context
    
    private var trading: Trading
    private var tradingViewController: UIViewController?
    
    init?(
        wallet: Wallet,
        supportedChainIDs: Set<String>? = nil, // nil for all
        trading: Trading?,
        sendAssetID: String?,
        receiveAssetID: String?,
        referral: String?,
    ) {
        var trading = trading
        ?? Trading(rawValue: AppGroupUserDefaults.Wallet.tradeMode)
        ?? .simpleSpot
        let allTradings: [Trading]
        switch wallet {
        case .privacy:
            allTradings = [.simpleSpot, .advancedSpot, .perpetualFutures]
        case .common:
            allTradings = [.simpleSpot, .advancedSpot]
        case .safe:
            allTradings = []
        }
        if allTradings.isEmpty {
            assertionFailure("Unsupported wallet")
            return nil
        } else if !allTradings.contains(trading) {
            trading = allTradings[0]
        }
        
        self.allTradings = allTradings
        self.wallet = wallet
        self.supportedChainIDs = supportedChainIDs
        self.trading = trading
        self.initialContext = Context(
            sendAssetID: sendAssetID,
            sendAmount: nil,
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
        
        title = R.string.localizable.trade()
        navigationItem.titleView = TradeTitleView(wallet: wallet)
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(presentOrders(_:)),
        )
        
        collectionView.register(R.nib.segmentCell)
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
        replaceChildViewController(trading: trading, focusOnInput: initialContext.hasAssetID)
    }
    
    func prepareForReuse() {
        
    }
    
    func switchTo(trading: Trading) {
        guard let item = allTradings.firstIndex(of: trading) else {
            return
        }
        let indexPath = IndexPath(item: item, section: 0)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        switchTo(trading: trading, indexPath: indexPath)
    }
    
    @objc private func presentOrders(_ sender: Any) {
        let menu = TradeMoreMenuViewController(wallet: wallet)
        let navigation = UINavigationController(rootViewController: menu)
        present(navigation, animated: true)
        let reportingTab = switch trading {
        case .simpleSpot:
            "swap"
        case .advancedSpot:
            "limit"
        case .perpetualFutures:
            "perps"
        }
        reporter.report(event: .tradeMoreMenu, tags: ["tab": reportingTab])
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
            cell.label.text = R.string.localizable.perpetual()
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
        switchTo(trading: trading, indexPath: indexPath)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
}

extension TradeViewController {
    
    private func switchTo(trading: Trading, indexPath: IndexPath) {
        switch trading {
        case .simpleSpot:
            break
        case .advancedSpot:
            BadgeManager.shared.setHasViewed(identifier: .advancedTrade)
        case .perpetualFutures:
            BadgeManager.shared.setHasViewed(identifier: .perps)
        }
        if let cell = collectionView.cellForItem(at: indexPath) as? SegmentCell {
            cell.badgeView.isHidden = true
        }
        AppGroupUserDefaults.Wallet.tradeMode = trading.rawValue
        self.trading = trading
        replaceChildViewController(trading: trading, focusOnInput: false)
    }
    
    private func replaceChildViewController(trading: Trading, focusOnInput: Bool) {
        var context: Context?
        if let tradingViewController {
            tradingViewController.willMove(toParent: nil)
            tradingViewController.view.removeFromSuperview()
            tradingViewController.removeFromParent()
            if let trading = tradingViewController as? TradeSpotViewController {
                context = Context(
                    sendAssetID: trading.sendToken?.assetID,
                    sendAmount: trading.pricingModel.sendAmount,
                    receiveAssetID: trading.receiveToken?.assetID,
                    referral: initialContext.referral
                )
            }
        } else {
            context = initialContext
        }
        
        let tradingViewController: UIViewController
        switch wallet {
        case .safe:
            assertionFailure("Unsupported wallet")
            return
        case .privacy:
            switch trading {
            case .simpleSpot:
                tradingViewController = TradeMixinSpotViewController(
                    mode: .simple,
                    sendAssetID: context?.sendAssetID,
                    sendAmount: context?.sendAmount,
                    receiveAssetID: context?.receiveAssetID,
                    referral: context?.referral,
                    focusOnInput: focusOnInput,
                )
            case .advancedSpot:
                tradingViewController = TradeMixinSpotViewController(
                    mode: .advanced,
                    sendAssetID: context?.sendAssetID,
                    sendAmount: context?.sendAmount,
                    receiveAssetID: context?.receiveAssetID,
                    referral: context?.referral,
                    focusOnInput: focusOnInput,
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
                    sendAmount: context?.sendAmount,
                    receiveAssetID: context?.receiveAssetID,
                    focusOnInput: focusOnInput,
                )
            case .advancedSpot:
                tradingViewController = TradeWeb3SpotViewController(
                    wallet: wallet,
                    mode: .advanced,
                    supportedChainIDs: supportedChainIDs,
                    sendAssetID: context?.sendAssetID,
                    sendAmount: context?.sendAmount,
                    receiveAssetID: context?.receiveAssetID,
                    focusOnInput: focusOnInput,
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
