import UIKit
import MixinServices

final class WalletSummaryViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case summary
        case wallets
        case tips
        case tipsPageControl
    }
    
    private enum ReuseIdentifier {
        static let pageControl = "p"
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var addWalletView: BadgeBarButtonView!
    
    private var summary: WalletSummary?
    private var privacyWalletDigest: WalletDigest?
    private var commonWalletDigests: [WalletDigest] = []
    private var tips: [WalletTipCell.Content] = []
    private var secretAvailableWalletIDs: Set<String> = []
    
    private weak var tipsPageControl: UIPageControl?
    private var tipsCurrentPage: Int = 0 {
        didSet {
            tipsPageControl?.currentPage = tipsCurrentPage
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addWalletView.button.setImage(R.image.ic_title_add(), for: .normal)
        addWalletView.button.addTarget(self, action: #selector(addWallet(_:)), for: .touchUpInside)
        addWalletView.badge = BadgeManager.shared.hasViewed(identifier: .addWallet) ? nil : .unread
        collectionView.register(R.nib.walletSummaryValueCell)
        collectionView.register(R.nib.walletCell)
        collectionView.register(R.nib.walletTipCell)
        collectionView.register(
            WalletTipPageControlCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.pageControl
        )
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .summary:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(152))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(152))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                return section
            case .wallets:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: nil)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
                return section
            case .tips:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(144))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(144))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
                section.orthogonalScrollingBehavior = .groupPaging
                section.visibleItemsInvalidationHandler = { (items, location, environment) in
                    let width = environment.container.contentSize.width
                    let pageOffset = location.x.truncatingRemainder(dividingBy: width)
                    if pageOffset < width / 5 {
                        self?.tipsCurrentPage = Int(location.x / width)
                    }
                }
                return section
            case .tipsPageControl:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            collectionView!,
            selector: #selector(collectionView.reloadData),
            name: Currency.currentCurrencyDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenDAO.tokensDidChangeNotification,
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
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3WalletDAO.walletsDidSaveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3WalletDAO.walletsDidDeleteNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadTips),
            name: AppGroupUserDefaults.Wallet.didChangeWalletTipNotification,
            object: nil
        )
        
        reloadData()
        reloadTips()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BadgeManager.shared.setHasViewed(identifier: .walletSwitch)
    }
    
    @objc private func addWallet(_ sender: Any) {
        addWalletView.badge = nil
        BadgeManager.shared.setHasViewed(identifier: .addWallet)
        let selector = AddWalletMethodSelectorViewController()
        selector.onSelected = { [weak self] method in
            let introduction = AddWalletIntroductionViewController(action: .addWallet(method))
            self?.navigationController?.pushViewController(introduction, animated: true)
        }
        present(selector, animated: true)
    }
    
    @objc private func reloadTips() {
        let tipsBefore = self.tips
        let tipsAfter = {
            var tips: [WalletTipCell.Content] = []
            if !AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip {
                tips.append(.privacy)
            }
            if !AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip {
                tips.append(.classic)
            }
            return tips
        }()
        guard tipsBefore != tipsAfter else {
            return
        }
        self.tips = tipsAfter
        if tipsBefore.isEmpty && !tipsAfter.isEmpty {
            collectionView.reloadData()
        } else if !tipsBefore.isEmpty && tipsAfter.isEmpty {
            if collectionView.window == nil {
                collectionView.reloadData()
            } else {
                let sections = IndexSet(arrayLiteral: Section.tips.rawValue, Section.tipsPageControl.rawValue)
                collectionView.deleteSections(sections)
            }
        } else {
            let deletedItem: Int
            if let index = tipsBefore.firstIndex(of: .privacy), !tipsAfter.contains(.privacy) {
                deletedItem = index
            } else if let index = tipsBefore.firstIndex(of: .classic), !tipsAfter.contains(.classic) {
                deletedItem = index
            } else {
                // Adding items, must be diagnose
                collectionView.reloadData()
                return
            }
            let indexPath = IndexPath(item: deletedItem, section: Section.tips.rawValue)
            collectionView.deleteItems(at: [indexPath])
            tipsPageControl?.numberOfPages = tips.count
            tipsCurrentPage = 0
        }
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async {
            let privacyWalletDigest = TokenDAO.shared.walletDigest()
            let commonWalletDigests = Web3WalletDAO.shared.walletDigests()
            let summary = WalletSummary(
                privacyWallet: privacyWalletDigest,
                otherWallets: commonWalletDigests
            )
            var secretAvailableWalletIDs: Set<String> = Set(
                AppGroupKeychain.allImportedMnemonics().keys
            )
            secretAvailableWalletIDs.formUnion(
                AppGroupKeychain.allImportedPrivateKey().keys
            )
            DispatchQueue.main.async {
                self.summary = summary
                self.privacyWalletDigest = privacyWalletDigest
                self.commonWalletDigests = commonWalletDigests
                self.secretAvailableWalletIDs = secretAvailableWalletIDs
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension WalletSummaryViewController: WalletTipCell.Delegate {
    
    func walletTipCellWantsToClose(_ cell: WalletTipCell) {
        guard let content = cell.content else {
            return
        }
        switch content {
        case .privacy:
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip = true
        case .classic:
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip = true
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sections: [Section] = [.summary, .wallets]
        if !tips.isEmpty {
            sections.append(.tips)
            sections.append(.tipsPageControl)
        }
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .summary:
            1
        case .wallets:
            1 + commonWalletDigests.count
        case .tips:
            tips.count
        case .tipsPageControl:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .summary:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_value, for: indexPath)!
            if let summary {
                cell.load(summary: summary)
            }
            cell.delegate = self
            return cell
        case .wallets:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            cell.accessory = .disclosure
            switch indexPath.item {
            case 0:
                if let digest = privacyWalletDigest {
                    cell.load(digest: digest, hasSecret: false)
                }
            default:
                let digest = commonWalletDigests[indexPath.row - 1]
                let hasSecret = switch digest.wallet {
                case .privacy:
                    false
                case .common(let wallet):
                    secretAvailableWalletIDs.contains(wallet.walletID)
                }
                cell.load(digest: digest, hasSecret: hasSecret)
            }
            return cell
        case .tips:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_tip_cell, for: indexPath)!
            cell.content = tips[indexPath.item]
            cell.delegate = self
            return cell
        case .tipsPageControl:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.pageControl, for: indexPath) as! WalletTipPageControlCell
            cell.pageControl.numberOfPages = tips.count
            cell.pageControl.currentPage = tipsCurrentPage
            self.tipsPageControl = cell.pageControl
            return cell
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .summary, .tips, .tipsPageControl:
            break
        case .wallets:
            let container = parent as? WalletContainerViewController
            switch indexPath.row {
            case 0:
                container?.switchToWallet(.privacy)
            default:
                let digest = commonWalletDigests[indexPath.row - 1]
                container?.switchToWallet(digest.wallet)
            }
        }
    }
    
}

extension WalletSummaryViewController: WalletSummaryValueCell.Delegate {
    
    func walletSummaryValueCellRequestTip(_ cell: WalletSummaryValueCell) {
        let tipView = R.nib.overlayTipView(withOwner: nil)!
        view.addSubview(tipView)
        tipView.snp.makeEdgesEqualToSuperview()
        tipView.label.text = R.string.localizable.wallet_summary_tip()
        view.layoutIfNeeded()
        let center = cell.convert(cell.infoButton.center, to: tipView)
        tipView.placeTip(at: center)
    }
    
}
