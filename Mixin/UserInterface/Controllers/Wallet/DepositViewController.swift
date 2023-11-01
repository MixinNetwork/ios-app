import UIKit
import OrderedCollections
import MixinServices

class DepositViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var upperDepositFieldView: DepositFieldView!
    @IBOutlet weak var lowerDepositFieldView: DepositFieldView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!
    
    private let usdtNetworkNames: OrderedDictionary<String, String> = [
        AssetID.ethereumUSDT:   "ERC-20",
        AssetID.tronUSDT:       "TRON(TRC-20)",
        AssetID.eosUSDT:        "EOS",
        AssetID.polygonUSDT:    "Polygon",
        AssetID.bep20USDT:      "BEP-20",
    ]
    
    private var token: TokenItem!
    private var addressGeneratingView: UIView?
    private var networkSwitchViewContentSizeObserver: NSKeyValueObservation?
    private var switchableNetworks: [String] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance(asset: TokenItem) -> UIViewController {
        let vc = R.storyboard.wallet.deposit()!
        vc.token = asset
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.deposit())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.setSubtitle(subtitle: token.symbol)
        view.layoutIfNeeded()
        let token = self.token!
        DispatchQueue.global().async {
            self.reloadEntry(token: token)
        }
//        if let index = usdtNetworkNames.index(forKey: token.assetId) {
//            switchableNetworks = usdtNetworkNames.values.elements
//            let switchView = R.nib.depositNetworkSwitchView(withOwner: nil)!
//            contentStackView.insertArrangedSubview(switchView, at: 0)
//            let collectionView: UICollectionView = switchView.collectionView
//            networkSwitchViewContentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
//                guard let newValue = change.newValue, let self else {
//                    return
//                }
//                switchView.collectionViewHeightConstraint.constant = newValue.height
//                self.view.layoutIfNeeded()
//            }
//            collectionView.register(R.nib.compactDepositNetworkCell)
//            collectionView.dataSource = self
//            collectionView.delegate = self
//            collectionView.reloadData()
//            let indexPath = IndexPath(item: index, section: 0)
//            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
//        }
    }
    
    private func reloadEntry(token: TokenItem) {
        if let entry = DepositEntryDAO.shared.entry(ofChainWith: token.chainID) {
            DispatchQueue.main.async {
                guard token.assetID == self.token.assetID, entry.isSignatureValid else {
                    return
                }
                self.updateViews(token: token, entry: entry)
                self.hideAddressGeneratingView()
            }
        } else {
            self.reloadEntryFromRemote(token: token)
        }
    }
    
    private func reloadEntryFromRemote(token: TokenItem) {
        Queue.main.autoAsync(execute: showAddressGeneratingView)
        SafeAPI.depositEntries(chainID: token.chainID) { [weak self] result in
            switch result {
            case .success(let entries):
                DepositEntryDAO.shared.save(entries: entries)
                if let entry = entries.first(where: \.isPrimary) {
                    if let self, token.assetID == self.token.assetID {
                        self.updateViews(token: token, entry: entry)
                        self.hideAddressGeneratingView()
                    }
                } else {
                    Logger.general.error(category: "Deposit", message: "No primary entry: \(token.name)")
                }
            case .failure(.invalidSignature):
                break
            case .failure(let error):
                Logger.general.error(category: "Deposit", message: "Failed to load: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadEntryFromRemote(token: token)
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
        let id = usdtNetworkNames.elements[indexPath.item].key
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
    
}
