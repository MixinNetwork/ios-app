import UIKit
import Combine
import OrderedCollections
import MixinServices

final class WalletSelectorViewController: UIViewController {
    
    protocol Delegate: AnyObject {
        func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectWallet wallet: Wallet)
        func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectMultipleWallets wallets: [Wallet])
    }
    
    enum Intent {
        
        // Multiple selections, all wallets
        case pickSwapOrderFilter(selectedWallets: [Wallet])
        
        // Single selection, wallets with secret only
        case pickSender
        
        // Single selection, all wallets
        case pickReceiver
        
    }
    
    private enum Section: Int, CaseIterable {
        case walletCategory
        case wallet
        case tips
        case tipsPageControl
    }
    
    private enum ReuseIdentifier {
        static let pageControl = "p"
    }
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: Delegate?
    
    private weak var tipsPageControl: UIPageControl?
    
    private let intent: Intent
    private let excludingWallet: Wallet?
    private let supportingChainID: String? // nil for all chains
    
    private var selections: [Wallet] // Works with Intent.pickSwapOrderFilter
    
    private var sections: [Section] = []
    private var allDigests: [WalletDigest] = []
    private var categorizedDigests: OrderedDictionary<WalletDisplayCategory, [WalletDigest]> = [:]
    private var selectedCategory: WalletDisplayCategory = .all
    private var secretAvailableWalletIDs: Set<String> = []
    
    private var searchObserver: AnyCancellable?
    private var searchingKeyword: String?
    private var searchResults: [WalletDigest]?
    
    private var tips: [WalletTipCell.Content] = []
    private var tipsCurrentPage: Int = 0 {
        didSet {
            tipsPageControl?.currentPage = tipsCurrentPage
        }
    }
    
    init(
        intent: Intent,
        excluding wallet: Wallet?,
        supportingChainWith chainID: String? // nil for all chains
    ) {
        self.intent = intent
        self.excludingWallet = wallet
        self.supportingChainID = chainID
        self.selections = switch intent {
        case .pickSwapOrderFilter(let wallets):
            wallets
        case .pickSender, .pickReceiver:
            []
        }
        let nib = R.nib.walletSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.contentView.backgroundColor = R.color.background()
        searchBoxView.textField.addTarget(self, action: #selector(prepareForSearch(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.name()
        searchObserver = NotificationCenter.default
            .publisher(for: UITextField.textDidChangeNotification, object: searchBoxView.textField)
            .debounce(for: .seconds(0.65), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                let keyword = self.searchBoxView.trimmedLowercaseText
                guard !keyword.isEmpty, keyword != self.searchingKeyword else {
                    self.searchBoxView.isBusy = false
                    return
                }
                self.search(keyword: keyword)
            }
        cancelButton.configuration?.title = R.string.localizable.cancel()
        switch intent {
        case .pickSwapOrderFilter:
            let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
            trayView.backgroundColor = R.color.background_secondary()
            UIView.performWithoutAnimation {
                trayView.leftButton.setTitle(R.string.localizable.reset(), for: .normal)
                trayView.leftButton.layoutIfNeeded()
                trayView.rightButton.setTitle(R.string.localizable.apply(), for: .normal)
                trayView.rightButton.layoutIfNeeded()
            }
            view.addSubview(trayView)
            trayView.snp.makeConstraints { make in
                make.top.equalTo(collectionView.snp.bottom)
                make.leading.trailing.bottom.equalTo(view)
            }
            trayView.leftButton.addTarget(self, action: #selector(resetSelections(_:)), for: .touchUpInside)
            trayView.rightButton.addTarget(self, action: #selector(applySelections(_:)), for: .touchUpInside)
        case .pickSender, .pickReceiver:
            collectionView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
            }
        }
        collectionView.allowsMultipleSelection = true
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.walletCell)
        collectionView.register(R.nib.walletTipCell)
        collectionView.register(
            WalletTipPageControlCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.pageControl
        )
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, _) in
            switch self?.section(at: sectionIndex) {
            case .walletCategory:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(38))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 5, trailing: 15)
                section.orthogonalScrollingBehavior = .continuous
                return section
            case .wallet:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: nil, trailing: nil, bottom: .fixed(5))
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
            case .tipsPageControl, .none:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        reloadData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: ReloadSafeWalletsJob.safeWalletsDidUpdateNotification,
            object: nil
        )
        let reloadSafeWallets = ReloadSafeWalletsJob()
        ConcurrentJobQueue.shared.addJob(job: reloadSafeWallets)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTips),
            name: AppGroupUserDefaults.Wallet.didChangeWalletTipNotification,
            object: nil
        )
        reloadTips()
    }
    
    @IBAction func cancel(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func prepareForSearch(_ textField: UITextField) {
        let keyword = searchBoxView.trimmedLowercaseText
        if keyword.isEmpty {
            searchingKeyword = nil
            searchResults = nil
            collectionView.reloadData()
            reloadSelections()
            searchBoxView.isBusy = false
        } else if keyword != searchingKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    @objc private func resetSelections(_ sender: Any) {
        searchingKeyword = nil
        searchResults = nil
        selections = []
        collectionView.reloadData()
        reloadSelections()
        searchBoxView.isBusy = false
    }
    
    @objc private func applySelections(_ sender: Any) {
        delegate?.walletSelectorViewController(self, didSelectMultipleWallets: selections)
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [intent, excludingWallet, supportingChainID] in
            var secretAvailableWalletIDs: Set<String> = Set(
                AppGroupKeychain.allImportedMnemonics().keys
            )
            secretAvailableWalletIDs.formUnion(
                AppGroupKeychain.allImportedPrivateKey().keys
            )
            
            let commonWallets = Web3WalletDAO.shared.walletDigests()
            let safeWallets = SafeWalletDAO.shared.walletDigests()
            var digests: [WalletDigest] = switch excludingWallet {
            case .none:
                [TokenDAO.shared.walletDigest()] + commonWallets + safeWallets
            case .privacy:
                commonWallets + safeWallets
            case .common:
                [TokenDAO.shared.walletDigest()]
                + commonWallets.filter { digest in
                    digest.wallet != excludingWallet
                }
                + safeWallets
            case .safe:
                [TokenDAO.shared.walletDigest()]
                + commonWallets
                + safeWallets.filter { digest in
                    digest.wallet != excludingWallet
                }
            }
            switch intent {
            case .pickSender:
                digests.removeAll { digest in
                    switch digest.wallet {
                    case .privacy:
                        false
                    case .common(let wallet):
                        switch wallet.category.knownCase {
                        case .classic:
                            false
                        case .importedMnemonic, .importedPrivateKey:
                            !secretAvailableWalletIDs.contains(wallet.walletID)
                        case .watchAddress, .none:
                            true
                        }
                    case .safe:
                        true
                    }
                }
            case .pickSwapOrderFilter:
                digests.removeAll { digest in
                    switch digest.wallet {
                    case .privacy:
                        false
                    case .common(let wallet):
                        switch wallet.category.knownCase {
                        case .classic, .importedMnemonic, .importedPrivateKey:
                            false
                        case .watchAddress, .none:
                            true
                        }
                    case .safe:
                        true
                    }
                }
            case .pickReceiver:
                break
            }
            if let supportingChainID {
                digests.removeAll { digest in
                    !digest.supportedChainIDs.contains(supportingChainID)
                }
            }
            
            var sections: [Section]
            let categorizedDigests: OrderedDictionary<WalletDisplayCategory, [WalletDigest]>
            switch intent {
            case .pickSwapOrderFilter:
                sections = [.wallet]
                categorizedDigests = [.all: digests]
            case .pickSender, .pickReceiver:
                sections = [.walletCategory, .wallet]
                categorizedDigests = WalletDisplayCategory.categorize(digests: digests)
                    .filter { category, wallets in
                        !wallets.isEmpty
                    }
            }
            
            DispatchQueue.main.async {
                if !self.tips.isEmpty {
                    sections.append(.tips)
                    sections.append(.tipsPageControl)
                }
                self.sections = sections
                self.allDigests = digests
                self.categorizedDigests = categorizedDigests
                if categorizedDigests[self.selectedCategory] == nil,
                   let firstCategory = categorizedDigests.keys.first
                {
                    self.selectedCategory = firstCategory
                }
                self.secretAvailableWalletIDs = secretAvailableWalletIDs
                if let keyword = self.searchingKeyword {
                    self.search(keyword: keyword)
                } else {
                    self.collectionView.reloadData()
                    self.reloadSelections()
                }
            }
        }
    }
    
    private func reloadSelections() {
        if searchResults == nil, let section = sections.firstIndex(of: .walletCategory) {
            let indexPath: IndexPath
            if let item = categorizedDigests.index(forKey: selectedCategory) {
                indexPath = IndexPath(item: item, section: section)
            } else {
                self.selectedCategory = .all
                indexPath = IndexPath(item: 0, section: section)
            }
            self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        switch intent {
        case .pickSwapOrderFilter:
            let digests = searchResults ?? categorizedDigests[selectedCategory] ?? []
            let selectedWalletIndices = digests.indices.filter { index in
                selections.contains(digests[index].wallet)
            }
            if let section = sections.firstIndex(of: .wallet) {
                let indexPaths = selectedWalletIndices.map { item in
                    IndexPath(item: item, section: section)
                }
                for indexPath in indexPaths {
                    collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                }
            }
        case .pickSender, .pickReceiver:
            break
        }
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
            if !AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip {
                tips.append(.safe)
            }
            return tips
        }()
        guard tipsBefore != tipsAfter else {
            return
        }
        self.tips = tipsAfter
        if tipsBefore.isEmpty && !tipsAfter.isEmpty {
            sections.append(contentsOf: [.tips, .tipsPageControl])
            collectionView.reloadData()
            reloadSelections()
        } else if !tipsBefore.isEmpty && tipsAfter.isEmpty {
            var deleteSections = IndexSet()
            if let index = sections.lastIndex(of: .tipsPageControl) {
                deleteSections.insert(index)
            }
            if let index = sections.lastIndex(of: .tips) {
                deleteSections.insert(index)
            }
            for index in deleteSections.sorted(by: >) {
                sections.remove(at: index)
            }
            if collectionView.window == nil {
                collectionView.reloadData()
                reloadSelections()
            } else {
                collectionView.deleteSections(deleteSections)
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
                reloadSelections()
                return
            }
            if let section = sections.firstIndex(of: .tips) {
                let indexPath = IndexPath(item: deletedItem, section: section)
                collectionView.deleteItems(at: [indexPath])
            }
            tipsPageControl?.numberOfPages = tips.count
            tipsCurrentPage = 0
        }
    }
    
    private func search(keyword: String) {
        searchingKeyword = keyword
        searchResults = allDigests.filter { digest in
            digest.wallet.localizedName.lowercased().contains(keyword)
        }
        collectionView.reloadData()
        reloadSelections()
        searchBoxView.isBusy = false
    }
    
    private func section(at sectionIndex: Int) -> Section {
        if searchResults == nil {
            sections[sectionIndex]
        } else {
            .wallet
        }
    }
    
}

extension WalletSelectorViewController: WalletTipCell.Delegate {
    
    func walletTipCellWantsToClose(_ cell: WalletTipCell) {
        guard let content = cell.content else {
            return
        }
        switch content {
        case .privacy:
            AppGroupUserDefaults.Wallet.hasViewedPrivacyWalletTip = true
        case .classic:
            AppGroupUserDefaults.Wallet.hasViewedClassicWalletTip = true
        case .safe:
            AppGroupUserDefaults.Wallet.hasViewedSafeWalletTip = true
        }
    }
    
}

extension WalletSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if searchResults == nil {
            sections.count
        } else {
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let searchResults {
            searchResults.count
        } else {
            switch sections[section] {
            case .walletCategory:
                categorizedDigests.count
            case .wallet:
                categorizedDigests[selectedCategory]?.count ?? 0
            case .tips:
                tips.count
            case .tipsPageControl:
                1
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch section(at: indexPath.section) {
        case .walletCategory:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            cell.label.text = categorizedDigests.keys[indexPath.item].localizedName
            return cell
        case .wallet:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            switch intent {
            case .pickSwapOrderFilter:
                cell.accessory = .selection
            case .pickSender, .pickReceiver:
                cell.accessory = .disclosure
            }
            let digest = if let searchResults {
                searchResults[indexPath.row]
            } else {
                categorizedDigests[selectedCategory]?[indexPath.row]
            }
            if let digest {
                let hasSecret = switch digest.wallet {
                case .privacy, .safe:
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

extension WalletSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch section(at: indexPath.section) {
        case .walletCategory, .wallet:
            true
        default:
            false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch section(at: indexPath.section) {
        case .tips, .tipsPageControl:
            break
        case .walletCategory:
            collectionView.indexPathsForSelectedItems?.forEach { selectedIndexPath in
                if selectedIndexPath.section == indexPath.section,
                   selectedIndexPath.item != indexPath.item
                {
                    collectionView.deselectItem(at: selectedIndexPath, animated: false)
                }
            }
            selectedCategory = categorizedDigests.keys[indexPath.item]
            if let section = sections.firstIndex(of: .wallet) {
                UIView.performWithoutAnimation {
                    let sections = IndexSet(integer: section)
                    collectionView.reloadSections(sections)
                }
            }
        case .wallet:
            let digest = if let searchResults {
                searchResults[indexPath.row]
            } else {
                categorizedDigests[selectedCategory]?[indexPath.row]
            }
            guard let digest else {
                return
            }
            switch intent {
            case .pickSwapOrderFilter:
                selections.append(digest.wallet)
            case .pickReceiver, .pickSender:
                let uncontrolledWallet: Web3Wallet?
                switch digest.wallet {
                case .privacy, .safe:
                    uncontrolledWallet = nil
                case .common(let wallet):
                    uncontrolledWallet = wallet.hasSecret() ? nil : wallet
                }
                if let wallet = uncontrolledWallet {
                    let warning = UncontrolledWalletWarningViewController(wallet: wallet)
                    warning.onConfirm = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.presentingViewController?.dismiss(animated: true) {
                            self.delegate?.walletSelectorViewController(self, didSelectWallet: digest.wallet)
                        }
                    }
                    present(warning, animated: true)
                } else {
                    presentingViewController?.dismiss(animated: true) {
                        self.delegate?.walletSelectorViewController(self, didSelectWallet: digest.wallet)
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        switch intent {
        case .pickSwapOrderFilter:
            let digest = if let searchResults {
                searchResults[indexPath.row]
            } else {
                categorizedDigests[selectedCategory]?[indexPath.row]
            }
            if let digest, let index = selections.firstIndex(of: digest.wallet) {
                selections.remove(at: index)
            }
        case .pickReceiver, .pickSender:
            break
        }
    }
    
}
