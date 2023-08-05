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
    
    private var asset: AssetItem!
    private var needsShowChooseNetworkWindow = true
    private var addressGeneratingView: UIView?
    private var networkSwitchViewContentSizeObserver: NSKeyValueObservation?
    private var switchableNetworks: [String] = []
    private var switchingToAssetID: String?
    
    private weak var job: RefreshAssetsJob?
    
    deinit {
        job?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        container?.setSubtitle(subtitle: asset.symbol)
        view.layoutIfNeeded()
        
        if let entry = asset.preferredDepositEntry, let chain = asset.chain {
            show(entry: entry)
            showChooseNetworkWindowIfNeeded(chain: chain)
        } else {
            showAddressGeneratingView()
        }
        
        if let index = usdtNetworkNames.index(forKey: asset.assetId) {
            switchableNetworks = usdtNetworkNames.values.elements
            let switchView = R.nib.depositNetworkSwitchView(owner: nil)!
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(assetsDidChange(_:)), name: AssetDAO.assetsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(chainsDidChange(_:)), name: ChainDAO.chainsDidChangeNotification, object: nil)
        let job = RefreshAssetsJob(request: .asset(id: asset.assetId, untilDepositEntriesNotEmpty: true))
        self.job = job
        ConcurrentJobQueue.shared.addJob(job: job)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = R.storyboard.wallet.deposit()!
        vc.asset = asset
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.deposit())
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
                                          centerView: .asset(asset))
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
        switchingToAssetID = id
        needsShowChooseNetworkWindow = true
        reloadAsset(with: id)
    }
    
}

extension DepositViewController {
    
    @objc private func assetsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[AssetDAO.UserInfoKey.assetId] as? String else {
            return
        }
        guard id == asset.assetId || id == switchingToAssetID else {
            return
        }
        switchingToAssetID = nil
        reloadAsset(with: id)
    }
    
    @objc private func chainsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[ChainDAO.UserInfoKey.chainId] as? String else {
            return
        }
        guard id == asset.assetId || id == switchingToAssetID else {
            return
        }
        switchingToAssetID = nil
        reloadAsset(with: id)
    }
    
    private func reloadAsset(with id: String) {
        DispatchQueue.global().async { [weak self] in
            if let asset = AssetDAO.shared.getAsset(assetId: id), let chain = asset.chain {
                DispatchQueue.main.sync {
                    guard let self = self else {
                        return
                    }
                    self.asset = asset
                    if let entry = asset.preferredDepositEntry {
                        UIView.performWithoutAnimation {
                            self.show(entry: entry)
                        }
                        self.hideAddressGeneratingView()
                        self.showChooseNetworkWindowIfNeeded(chain: chain)
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    guard let self = self else {
                        return
                    }
                    self.showAddressGeneratingView()
                    let job = RefreshAssetsJob(request: .asset(id: id, untilDepositEntriesNotEmpty: true))
                    self.job = job
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
        }
    }
    
    private func show(entry: Asset.DepositEntry) {
        upperDepositFieldView.titleLabel.text = R.string.localizable.address()
        upperDepositFieldView.contentLabel.text = entry.destination
        let nameImage = UIImage(qrcode: entry.destination, size: upperDepositFieldView.qrCodeImageView.bounds.size)
        upperDepositFieldView.qrCodeImageView.image = nameImage
        upperDepositFieldView.assetIconView.setIcon(asset: asset)
        upperDepositFieldView.shadowView.hasLowerShadow = true
        upperDepositFieldView.delegate = self
        if !entry.tag.isEmpty {
            lowerDepositFieldView.isHidden = false
            if asset.usesTag {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.tag()
            } else {
                lowerDepositFieldView.titleLabel.text = R.string.localizable.withdrawal_memo()
            }
            lowerDepositFieldView.contentLabel.text = entry.tag
            let memoImage = UIImage(qrcode: entry.tag, size: lowerDepositFieldView.qrCodeImageView.bounds.size)
            lowerDepositFieldView.qrCodeImageView.image = memoImage
            lowerDepositFieldView.assetIconView.setIcon(asset: asset)
            lowerDepositFieldView.shadowView.hasLowerShadow = false
            lowerDepositFieldView.delegate = self
            warningLabel.text = R.string.localizable.deposit_account_attention(asset.symbol)
        } else {
            lowerDepositFieldView.isHidden = true
            if asset.reserve.doubleValue > 0 {
                warningLabel.text = R.string.localizable.deposit_attention() +  R.string.localizable.deposit_at_least(asset.reserve, asset.chain?.symbol ?? "")
            } else {
                warningLabel.text = R.string.localizable.deposit_attention()
            }
        }
        hintLabel.text = asset.depositTips
    }
    
    private func showChooseNetworkWindowIfNeeded(chain: Chain) {
        guard needsShowChooseNetworkWindow else {
            return
        }
        needsShowChooseNetworkWindow = false
        DepositChooseNetworkWindow.instance().render(asset: asset, chain: chain).presentPopupControllerAnimated()
    }
    
    private func showAddressGeneratingView() {
        guard self.addressGeneratingView == nil else {
            return
        }
        let generatingView = R.nib.depositAddressGeneratingView(owner: nil)!
        view.addSubview(generatingView)
        generatingView.snp.makeEdgesEqualToSuperview()
        self.addressGeneratingView = generatingView
    }
    
    private func hideAddressGeneratingView() {
        addressGeneratingView?.removeFromSuperview()
        addressGeneratingView = nil
    }
    
}
