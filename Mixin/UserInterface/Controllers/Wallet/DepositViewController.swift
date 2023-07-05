import UIKit
import OrderedCollections
import MixinServices

class DepositViewController: UIViewController {
    
    private enum NetworkSwitchableAsset {
        case btc
        case usdt
    }
    
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
    private var networkSwitchableAsset: NetworkSwitchableAsset?
    private var hasDepositChooseNetworkWindowPresented = false
    private var addressGeneratingView: UIView?
    private var networkSwitchViewObserver: NSKeyValueObservation?
    private var switchableNetworks: [String] = []
    
    private lazy var depositWindow = QrcodeWindow.instance()
    
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
            showDepositChooseNetworkWindowIfNeeded(chain: chain)
        } else {
            let generatingView = R.nib.depositAddressGeneratingView(owner: nil)!
            view.addSubview(generatingView)
            generatingView.snp.makeEdgesEqualToSuperview()
            self.addressGeneratingView = generatingView
        }
        
        if asset.assetId == AssetID.btc && asset.depositEntries.count == 2 {
            networkSwitchableAsset = .btc
            switchableNetworks = ["Bitcoin(Segwit)", "Bitcoin"]
            insertNetworkSwitchView(selectedIndex: 0)
        } else if let index = usdtNetworkNames.index(forKey: asset.assetId) {
            networkSwitchableAsset = .usdt
            switchableNetworks = usdtNetworkNames.values.elements
            insertNetworkSwitchView(selectedIndex: index)
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
    
    private func insertNetworkSwitchView(selectedIndex: Int) {
        let switchView = R.nib.depositNetworkSwitchView(owner: nil)!
        contentStackView.insertArrangedSubview(switchView, at: 0)
        let collectionView: UICollectionView = switchView.collectionView
        networkSwitchViewObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
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
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
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
        depositWindow.render(title: view.titleLabel.text ?? "",
                             content: view.contentLabel.text ?? "",
                             asset: asset)
        depositWindow.presentView()
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
        switch networkSwitchableAsset {
        case .none:
            break
        case .btc:
            if indexPath.item == 0 {
                if let entry = asset.depositEntries.first(where: { $0.payToWitness }) {
                    show(entry: entry)
                }
            } else {
                if let entry = asset.depositEntries.first(where: { !$0.payToWitness }) {
                    show(entry: entry)
                }
            }
        case .usdt:
            let id = usdtNetworkNames.elements[indexPath.item].key
            reloadAsset(with: id)
        }
    }
    
}

extension DepositViewController {
    
    @objc private func assetsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[AssetDAO.UserInfoKey.assetId] as? String else {
            return
        }
        guard id == asset.assetId else {
            return
        }
        reloadAsset(with: id)
    }
    
    @objc private func chainsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[ChainDAO.UserInfoKey.chainId] as? String else {
            return
        }
        guard id == asset.chainId else {
            return
        }
        reloadAsset(with: id)
    }
    
    private func reloadAsset(with id: String) {
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: id), let chain = asset.chain else {
                return
            }
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.asset = asset
                if let entry = asset.preferredDepositEntry {
                    self.addressGeneratingView?.removeFromSuperview()
                    UIView.performWithoutAnimation {
                        self.show(entry: entry)
                    }
                    self.showDepositChooseNetworkWindowIfNeeded(chain: chain)
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
    
    private func showDepositChooseNetworkWindowIfNeeded(chain: Chain) {
        guard !hasDepositChooseNetworkWindowPresented else {
            return
        }
        hasDepositChooseNetworkWindowPresented = true
        DepositChooseNetworkWindow.instance().render(asset: asset, chain: chain).presentPopupControllerAnimated()
    }
    
}
