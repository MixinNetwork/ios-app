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
        static let tip = "t"
        static let pageControl = "p"
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var summary: WalletSummary?
    private var privacyWalletDigest: WalletDigest?
    private var classicWalletDigests: [WalletDigest] = []
    private var tips: [WalletTipView.Content] = []
    
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
        if !AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip {
            tips.append(.privacy)
        }
        if !AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip {
            tips.append(.classic)
        }
        collectionView.register(R.nib.walletSummaryValueCell)
        collectionView.register(R.nib.walletCell)
        collectionView.register(
            WalletTipCollectionViewCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.tip
        )
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
                group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: .fixed(5))
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 0)
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
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func reloadData() {
        BadgeManager.shared.setHasViewed(identifier: .walletSwitch)
        DispatchQueue.global().async {
            let privacyWalletDigest = TokenDAO.shared.walletDigest()
            let classicWalletDigests = Web3WalletDAO.shared.walletDigests()
            let summary = WalletSummary(
                privacyWallet: privacyWalletDigest,
                otherWallets: classicWalletDigests
            )
            DispatchQueue.main.async {
                self.summary = summary
                self.privacyWalletDigest = privacyWalletDigest
                self.classicWalletDigests = classicWalletDigests
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension WalletSummaryViewController: WalletTipView.Delegate {
    
    func walletTipViewWantsToClose(_ view: WalletTipView) {
        guard let content = view.content, let item = tips.firstIndex(of: content) else {
            return
        }
        tips.remove(at: item)
        if tips.isEmpty {
            let sections = IndexSet([Section.tips.rawValue, Section.tipsPageControl.rawValue])
            collectionView.deleteSections(sections)
        } else {
            let indexPath = IndexPath(item: item, section: Section.tips.rawValue)
            collectionView.deleteItems(at: [indexPath])
            tipsPageControl?.numberOfPages = tips.count
            tipsCurrentPage = 0
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
            1 + classicWalletDigests.count
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
            return cell
        case .wallets:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            switch indexPath.item {
            case 0:
                if let digest = privacyWalletDigest {
                    cell.load(digest: digest, type: .privacy)
                }
            default:
                let digest = classicWalletDigests[indexPath.row - 1]
                cell.load(digest: digest, type: .classic)
            }
            return cell
        case .tips:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier.tip, for: indexPath) as! WalletTipCollectionViewCell
            cell.tipView.content = tips[indexPath.item]
            cell.tipView.delegate = self
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
                let digest = classicWalletDigests[indexPath.row - 1]
                container?.switchToWallet(digest.wallet)
            }
        }
    }
    
}

extension WalletSummaryViewController {
    
    private final class WalletTipCollectionViewCell: UICollectionViewCell {
        
        let tipView = R.nib.walletTipView(withOwner: nil)!
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            prepare()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            prepare()
        }
        
        private func prepare() {
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            contentView.addSubview(tipView)
            tipView.snp.makeEdgesEqualToSuperview()
        }
        
    }
    
}
