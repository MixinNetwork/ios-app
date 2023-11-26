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
        AssetID.ethereumUSDT:   "ERC-20",
        AssetID.tronUSDT:       "TRON(TRC-20)",
        AssetID.eosUSDT:        "EOS",
        AssetID.polygonUSDT:    "Polygon",
        AssetID.bep20USDT:      "BEP-20",
    ]
    
    // `assetID` is the SSoT of current selected token
    // When user selects from USDT networks, `assetID` is updated immediately, while `token` is not
    private var assetID: String
    private var token: TokenItem
    
    private var displayingEntry: DepositEntry?
    
    private var addressGeneratingView: UIView?
    private var networkSwitchViewContentSizeObserver: NSKeyValueObservation?
    private var switchableNetworks: [String] = []
    
    init(token: TokenItem) {
        self.assetID = token.assetID
        self.token = token
        let nib = R.nib.depositView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    class func instance(token: TokenItem) -> UIViewController {
        let deposit = DepositViewController(token: token)
        return ContainerViewController.instance(viewController: deposit, title: R.string.localizable.deposit())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.setSubtitle(subtitle: token.symbol)
        reloadData(token: token)
        view.layoutIfNeeded()
        if let index = usdtNetworks.index(forKey: token.assetID) {
            switchableNetworks = usdtNetworks.values.elements
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
    
    private func reloadData(token: TokenItem) {
        DispatchQueue.global().async {
            self.reloadFromLocal(token: token)
            self.reloadFromRemote(token: token)
        }
    }
    
    private func reloadFromLocal(token: TokenItem) {
        guard let entry = DepositEntryDAO.shared.primaryEntry(ofChainWith: token.chainID) else {
            DispatchQueue.main.async {
                guard self.assetID == token.assetID else {
                    return
                }
                self.showAddressGeneratingView()
            }
            return
        }
        DispatchQueue.main.sync {
            guard token.assetID == self.assetID else {
                return
            }
            self.presentAddressChangedHintIfNeeded(token: token, newEntry: entry)
            self.updateViews(token: token, entry: entry)
            self.displayingEntry = entry
            self.hideAddressGeneratingView()
        }
    }
    
    private func reloadFromRemote(token: TokenItem) {
        SafeAPI.depositEntries(chainID: token.chainID, queue: .global()) { [weak self] result in
            switch result {
            case .success(let entries):
                DepositEntryDAO.shared.save(entries: entries) {
                    DispatchQueue.global().async {
                        self?.reloadFromLocal(token: token)
                    }
                }
            case .failure(.invalidSignature):
                break
            case .failure(let error):
                Logger.general.error(category: "Deposit", message: "Failed to load: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    guard let self, self.assetID == token.assetID else {
                        return
                    }
                    self.reloadFromRemote(token: token)
                }
            }
        }
    }
    
}

extension DepositViewController: ContainerViewControllerDelegate {
    
    var prefersNavigationBarSeparatorLineHidden: Bool {
        return true
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_titlebar_help()
    }
    
    func barRightButtonTappedAction() {
        UIApplication.shared.openURL(url: .deposit)
    }
    
}

extension DepositViewController: DepositFieldViewDelegate {
    
    func depositFieldViewDidCopyContent(_ view: DepositFieldView) {
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView) {
        guard let content = view.contentLabel.text else {
            return
        }
        let qrCode = QRCodeViewController(title: view.titleLabel.text ?? "",
                                          content: content,
                                          foregroundColor: .black,
                                          description: content,
                                          centerView: .asset(token))
        present(qrCode, animated: true)
    }
    
}

extension DepositViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switchableNetworks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.compact_deposit_network, for: indexPath)!
        cell.label.text = switchableNetworks[indexPath.item]
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
}

extension DepositViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let id = usdtNetworks.elements[indexPath.item].key
        self.showAddressGeneratingView()
        self.assetID = id
        Task { [weak self] in
            func reloadData(with token: TokenItem) async {
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    // No need to check `assetID` because generating view is blocking UI interactions
                    self.token = token
                    self.container?.setSubtitle(subtitle: token.symbol)
                    self.reloadData(token: token)
                }
            }
            
            if let token = TokenDAO.shared.tokenItem(with: id) {
                await reloadData(with: token)
            } else {
                let token = try await SafeAPI.assets(id: id)
                TokenDAO.shared.save(assets: [token])
                
                let chain: Chain
                if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                    chain = localChain
                } else {
                    chain = try await NetworkAPI.chain(id: token.chainID)
                    ChainDAO.shared.save([chain])
                }
                
                let tokenItem = TokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                await reloadData(with: tokenItem)
            }
        }
    }
    
}

extension DepositViewController {
    
    private func updateViews(token: TokenItem, entry: DepositEntry) {
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
            upperDepositFieldView.qrCodeImageView.image = UIImage(qrcode: tag, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.assetIconView.setIcon(token: token)
            
            lowerDepositFieldView.titleLabel.text = R.string.localizable.address()
            lowerDepositFieldView.contentLabel.text = entry.destination
            lowerDepositFieldView.qrCodeImageView.image = UIImage(qrcode: entry.destination, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.assetIconView.setIcon(token: token)
            lowerDepositFieldView.isHidden = false
            
            warningLabel.text = R.string.localizable.deposit_account_attention(token.symbol)
        } else {
            upperDepositFieldView.titleLabel.text = R.string.localizable.address()
            upperDepositFieldView.contentLabel.text = entry.destination
            upperDepositFieldView.qrCodeImageView.image = UIImage(qrcode: entry.destination, size: upperDepositFieldView.qrCodeImageView.bounds.size)
            upperDepositFieldView.assetIconView.setIcon(token: token)
            upperDepositFieldView.shadowView.hasLowerShadow = true
            upperDepositFieldView.delegate = self
            
            lowerDepositFieldView.isHidden = true
            
            if token.decimalDust > 0 {
                let dust = CurrencyFormatter.localizedString(from: token.decimalDust, format: .precision, sign: .never)
                warningLabel.text = R.string.localizable.deposit_attention() +  R.string.localizable.deposit_at_least(dust, token.chain?.symbol ?? "")
            } else {
                warningLabel.text = R.string.localizable.deposit_attention()
            }
        }
        hintLabel.text = token.depositTips
    }
    
    private func showChooseNetworkWindowIfNeeded(chain: Chain) {
        DepositChooseNetworkWindow.instance().render(token: token, chain: chain).presentPopupControllerAnimated()
    }
    
    private func showAddressGeneratingView() {
        guard self.addressGeneratingView == nil else {
            return
        }
        let generatingView = R.nib.depositAddressGeneratingView(withOwner: nil)!
        view.addSubview(generatingView)
        generatingView.snp.makeEdgesEqualToSuperview()
        self.addressGeneratingView = generatingView
    }
    
    private func hideAddressGeneratingView() {
        addressGeneratingView?.removeFromSuperview()
        addressGeneratingView = nil
    }
    
    private func presentAddressChangedHintIfNeeded(token: TokenItem, newEntry: DepositEntry) {
        guard let oldEntry = displayingEntry, oldEntry.chainID == newEntry.chainID else {
            return
        }
        guard oldEntry.destination != newEntry.destination || oldEntry.tag != newEntry.tag else {
            return
        }
        let hint = WalletHintViewController(token: token)
        hint.setTitle(R.string.localizable.depost_address_updated(token.symbol),
                      description: R.string.localizable.depost_address_updated_description(token.symbol))
        hint.delegate = self
        present(hint, animated: true)
    }
    
}

extension DepositViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeViewController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}
