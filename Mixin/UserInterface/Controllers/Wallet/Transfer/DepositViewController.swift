import UIKit
import OrderedCollections
import MixinServices

final class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    
    private let usdtNetworks: OrderedDictionary<String, String> = [
        AssetID.erc20USDT:      "ERC-20",
        AssetID.tronUSDT:       "TRON(TRC-20)",
        AssetID.polygonUSDT:    "Polygon",
        AssetID.bep20USDT:      "BEP-20",
        AssetID.solanaUSDT:     "Solana",
    ]
    
    private let usdcNetworks: OrderedDictionary<String, String> = [
        AssetID.erc20USDC:      "ERC-20",
        AssetID.solanaUSDC:     "Solana",
        AssetID.baseUSDC:       "Base",
        AssetID.polygonUSDC:    "Polygon",
        AssetID.bep20USDC:      "BEP-20",
    ]
    
    private let ethNetworks: OrderedDictionary<String, String> = [
        AssetID.eth:            "Ethereum",
        AssetID.baseETH:        "Base",
        AssetID.opMainnetETH:   "Optimism",
        AssetID.arbitrumOneETH: "Arbitrum",
    ]
    
    private let initialToken: MixinTokenItem
    
    private var addressGeneratingView: UIView?
    private var depositSuspendedView: DepositSuspendedView?
    
    private var networkSwitchViewContentSizeObserver: NSKeyValueObservation?
    private var switchableNetworks: OrderedDictionary<String, String> = [:]
    
    private var task: Task<Void, Error>?
    private var displayingToken: MixinTokenItem?
    
    private weak var titleView: NavigationTitleView!
    
    init(token: MixinTokenItem) {
        self.initialToken = token
        let nib = R.nib.depositView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        reporter.report(event: .receiveEnd)
        task?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.deposit()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_titlebar_help(),
            target: self,
            action: #selector(help(_:))
        )
        let titleView = NavigationTitleView(
            title: R.string.localizable.deposit(),
            subtitle: initialToken.symbol
        )
        self.titleView = titleView
        navigationItem.titleView = titleView
        addAddressGeneratingView()
        task = Task { [initialToken] in
            try await self.reloadData(token: initialToken)
        }
        
        let (switchableNetworks, selectedNetworkIndex): (OrderedDictionary<String, String>, Int?) = {
            let selectableNetworks = [usdtNetworks, usdcNetworks, ethNetworks]
            for networks in selectableNetworks {
                if let index = networks.index(forKey: initialToken.assetID) {
                    return (networks, index)
                }
            }
            return ([:], nil)
        }()
        self.switchableNetworks = switchableNetworks
        if let index = selectedNetworkIndex {
            let switchView = R.nib.depositNetworkSwitchView(withOwner: nil)!
            contentStackView.insertArrangedSubview(switchView, at: 0)
            let collectionView: UICollectionView = switchView.collectionView
            networkSwitchViewContentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
                guard let newValue = change.newValue, let self else {
                    return
                }
                switchView.collectionViewHeightConstraint.constant = newValue.height
                self.view.layoutIfNeeded()
            }
            collectionView.register(R.nib.compactDepositNetworkCell)
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.reloadData()
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
        }
    }
    
    @objc private func contactSupport(_ sender: Any) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeTabBarController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    @objc private func help(_ sender: Any) {
        UIApplication.shared.openURL(url: .deposit)
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
    func depositFieldViewDidCopyContent(_ view: DepositFieldView) {
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView) {
        guard let content = view.contentLabel.text, let token = displayingToken else {
            return
        }
        let qrCode = QRCodeViewController(title: view.titleLabel.text ?? "",
                                          content: content,
                                          foregroundColor: .black,
                                          description: content,
                                          centerContent: .asset(token))
        present(qrCode, animated: true)
    }
    
}

extension DepositViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switchableNetworks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.compact_deposit_network, for: indexPath)!
        cell.label.text = switchableNetworks.values[indexPath.item]
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
}

extension DepositViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = switchableNetworks.keys[indexPath.item]
        let previousTask = self.task
        addAddressGeneratingView()
        task = Task.detached { [weak self] in
            if let previousTask {
                previousTask.cancel()
                let _ = await previousTask.result
                try Task.checkCancellation()
            }
            
            let token: MixinTokenItem
            if let localToken = TokenDAO.shared.tokenItem(assetID: id) {
                token = localToken
            } else {
                await MainActor.run { [weak self] in
                    self?.addAddressGeneratingView()
                }
                let remoteToken = try await Self.withAutoRetrying {
                    try await SafeAPI.assets(id: id)
                }
                TokenDAO.shared.save(assets: [remoteToken])
                token = MixinTokenItem(token: remoteToken, balance: "0", isHidden: false, chain: nil)
                try Task.checkCancellation()
            }
            
            try await self?.reloadData(token: token)
        }
    }
    
}

extension DepositViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        contactSupport(controller)
    }
    
}

extension DepositViewController {
    
    private static func withAutoRetrying<Result>(
        interval: TimeInterval = 3,
        execute block: () async throws -> Result
    ) async throws -> Result {
        repeat {
            try Task.checkCancellation()
            do {
                return try await block()
            } catch {
                switch error {
                case MixinAPIResponseError.unauthorized, MixinAPIResponseError.addressGenerating:
                    throw error
                default:
                    try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                }
            }
        } while LoginManager.shared.isLoggedIn
        throw MixinAPIResponseError.unauthorized
    }
    
    private func reloadData(token: MixinTokenItem) async throws {
        Task.detached { [weak self] in
            let chain: Chain
            if let tokenChain = token.chain {
                chain = tokenChain
            } else if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                chain = localChain
            } else {
                chain = try await Self.withAutoRetrying {
                    try await NetworkAPI.chain(id: token.chainID)
                }
                ChainDAO.shared.save([chain])
                Web3ChainDAO.shared.save([chain])
                try Task.checkCancellation()
            }
            
            let localEntry = DepositEntryDAO.shared.primaryEntry(ofChainWith: chain.chainId)
            try Task.checkCancellation()
            
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.view.window != nil, let container = UIApplication.homeContainerViewController else {
                        continuation.resume(with: .failure(CancellationError()))
                        return
                    }
                    let selector = DepositNetworkSelectorViewController(token: token, chain: chain)
                    selector.onDismiss = {
                        continuation.resume(with: .success(()))
                    }
                    container.present(selector, animated: true)
                }
            }
            
            await MainActor.run { [weak self] in
                guard let self, let localEntry else {
                    return
                }
                self.titleView.subtitle = token.symbol
                self.displayingToken = token
                self.updateViews(token: token, entry: localEntry)
                self.removeAddressGeneratingView()
                self.removeDepositSuspendedView()
            }
            
            do {
                let remoteEntries = try await Self.withAutoRetrying {
                    try await SafeAPI.depositEntries(assetID: token.assetID, chainID: chain.chainId)
                }
                DepositEntryDAO.shared.replace(entries: remoteEntries, forChainWith: token.chainID)
                if let remoteEntry = remoteEntries.first(where: { $0.chainID == chain.chainId && $0.isPrimary }) {
                    try Task.checkCancellation()
                    await MainActor.run { [weak self] in
                        guard let self else {
                            return
                        }
                        self.displayingToken = token
                        self.updateViews(token: token, entry: remoteEntry)
                        self.removeAddressGeneratingView()
                        self.removeDepositSuspendedView()
                        
                        let isAddressChanged: Bool = if let localEntry {
                            localEntry.destination != remoteEntry.destination || localEntry.tag != remoteEntry.tag
                        } else {
                            false
                        }
                        guard isAddressChanged, let container = UIApplication.homeContainerViewController else {
                            return
                        }
                        let hint = WalletHintViewController(content: .addressUpdated(token))
                        hint.delegate = self
                        container.present(hint, animated: true)
                    }
                }
            } catch MixinAPIResponseError.addressGenerating {
                await MainActor.run { [weak self] in
                    self?.addDepositSuspendedView(token: token)
                }
            } catch {
                // Only `addressGenerating` and `unauthorized` could be thrown
                // Do nothing when encountered
            }
        }
    }
    
    private func updateViews(token: MixinTokenItem, entry: DepositEntry) {
        contentStackView.isHidden = false
        upperDepositFieldView.shadowView.hasLowerShadow = true
        upperDepositFieldView.delegate = self
        lowerDepositFieldView.shadowView.hasLowerShadow = false
        lowerDepositFieldView.delegate = self
        if let tag = entry.tag, !tag.isEmpty {
            if token.usesTag {
                upperDepositFieldView.titleLabel.text = R.string.localizable.tag()
            } else {
                upperDepositFieldView.titleLabel.text = R.string.localizable.withdrawal_memo()
            }
            upperDepositFieldView.contentLabel.text = entry.tag
            upperDepositFieldView.setQRCode(with: tag)
            upperDepositFieldView.assetIconView.setIcon(token: token)
            
            lowerDepositFieldView.titleLabel.text = R.string.localizable.address()
            lowerDepositFieldView.contentLabel.text = entry.destination
            lowerDepositFieldView.setQRCode(with: entry.destination)
            lowerDepositFieldView.assetIconView.setIcon(token: token)
            lowerDepositFieldView.isHidden = false
            
            warningLabel.text = R.string.localizable.deposit_account_attention(token.symbol)
        } else {
            upperDepositFieldView.titleLabel.text = R.string.localizable.address()
            upperDepositFieldView.contentLabel.text = entry.destination
            upperDepositFieldView.setQRCode(with: entry.destination)
            upperDepositFieldView.assetIconView.setIcon(token: token)
            upperDepositFieldView.shadowView.hasLowerShadow = true
            upperDepositFieldView.delegate = self
            
            lowerDepositFieldView.isHidden = true
            
            if token.decimalDust > 0 {
                let dust = CurrencyFormatter.localizedString(from: token.decimalDust, format: .precision, sign: .never)
                warningLabel.text = R.string.localizable.deposit_attention() + "\n" + R.string.localizable.deposit_dust(dust, token.symbol)
            } else {
                warningLabel.text = R.string.localizable.deposit_attention()
            }
        }
        hintLabel.text = token.depositTips
    }
    
    private func addAddressGeneratingView() {
        guard self.addressGeneratingView == nil else {
            return
        }
        let generatingView = R.nib.depositAddressGeneratingView(withOwner: nil)!
        view.addSubview(generatingView)
        generatingView.snp.makeEdgesEqualToSuperview()
        self.addressGeneratingView = generatingView
    }
    
    private func removeAddressGeneratingView() {
        addressGeneratingView?.removeFromSuperview()
        addressGeneratingView = nil
    }
    
    private func addDepositSuspendedView(token: MixinTokenItem) {
        let suspended: DepositSuspendedView
        if let depositSuspendedView {
            suspended = depositSuspendedView
        } else {
            suspended = R.nib.depositSuspendedView(withOwner: nil)!
            suspended.contactSupportButton.addTarget(self, action: #selector(contactSupport(_:)), for: .touchUpInside)
            view.addSubview(suspended)
            suspended.snp.makeEdgesEqualToSuperview()
        }
        suspended.symbol = if token.assetID == AssetID.omniUSDT {
            "OMNI - USDT"
        } else {
            token.symbol
        }
        suspended.isHidden = false
        depositSuspendedView = suspended
    }
    
    private func removeDepositSuspendedView() {
        depositSuspendedView?.isHidden = true
    }
    
}
