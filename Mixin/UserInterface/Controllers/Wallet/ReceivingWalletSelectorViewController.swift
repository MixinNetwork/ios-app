import UIKit
import Combine
import MixinServices

final class ReceivingWalletSelectorViewController: UIViewController {
    
    protocol Delegate: AnyObject {
        func receivingWalletSelectorViewController(_ viewController: ReceivingWalletSelectorViewController, didSelectWallet wallet: Wallet)
    }
    
    private enum Section: Int, CaseIterable {
        case wallets
        case tips
        case tipsPageControl
    }
    
    private enum ReuseIdentifier {
        static let tip = "t"
        static let pageControl = "p"
    }
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: Delegate?
    
    private weak var tipsPageControl: UIPageControl?
    
    private let excludingWallet: Wallet
    private let chainID: String
    
    private var walletDigests: [WalletDigest] = []
    private var searchObserver: AnyCancellable?
    private var searchingKeyword: String?
    private var searchResults: [WalletDigest]?
    private var secretAvailableWalletIDs: Set<String> = []
    
    private var tips: [WalletTipView.Content] = []
    private var tipsCurrentPage: Int = 0 {
        didSet {
            tipsPageControl?.currentPage = tipsCurrentPage
        }
    }
    
    init(excluding wallet: Wallet, supportingChainWith chainID: String) {
        self.excludingWallet = wallet
        self.chainID = chainID
        let nib = R.nib.receivingWalletSelectorView
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
        collectionView.register(R.nib.walletCell)
        collectionView.register(
            WalletTipCollectionViewCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.tip
        )
        collectionView.register(
            WalletTipPageControlCell.self,
            forCellWithReuseIdentifier: ReuseIdentifier.pageControl
        )
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, _) in
            switch Section(rawValue: sectionIndex)! {
            case .wallets:
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
            case .tipsPageControl:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(28))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        DispatchQueue.global().async { [excludingWallet, chainID] in
            let web3Wallets = Web3WalletDAO.shared.walletDigests()
            
            var digests: [WalletDigest] = switch excludingWallet {
            case .privacy:
                web3Wallets
            case .common:
                [TokenDAO.shared.walletDigest()] + web3Wallets.filter { digest in
                    digest.wallet != excludingWallet
                }
            }
            
            digests.removeAll { digest in
                !digest.supportedChainIDs.contains(chainID)
            }
            
            var secretAvailableWalletIDs: Set<String> = Set(
                AppGroupKeychain.allImportedMnemonics().keys
            )
            secretAvailableWalletIDs.formUnion(
                AppGroupKeychain.allImportedPrivateKey().keys
            )
            
            DispatchQueue.main.async {
                self.walletDigests = digests
                self.secretAvailableWalletIDs = secretAvailableWalletIDs
                self.collectionView.reloadData()
            }
        }
        
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
            searchBoxView.isBusy = false
        } else if keyword != searchingKeyword {
            searchBoxView.isBusy = true
        }
    }
    
    @objc private func reloadTips() {
        let tipsBefore = self.tips
        let tipsAfter = {
            var tips: [WalletTipView.Content] = []
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
    
    private func search(keyword: String) {
        searchingKeyword = keyword
        searchResults = walletDigests.filter { digest in
            digest.wallet.localizedName.lowercased().contains(keyword)
        }
        collectionView.reloadData()
        searchBoxView.isBusy = false
    }
    
}

extension ReceivingWalletSelectorViewController: WalletTipView.Delegate {
    
    func walletTipViewWantsToClose(_ view: WalletTipView) {
        guard let content = view.content else {
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

extension ReceivingWalletSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sections: [Section] = [.wallets]
        if !tips.isEmpty {
            sections.append(.tips)
            sections.append(.tipsPageControl)
        }
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .wallets:
            if let searchResults {
                searchResults.count
            } else {
                walletDigests.count
            }
        case .tips:
            tips.count
        case .tipsPageControl:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .wallets:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            let digest = if let searchResults {
                searchResults[indexPath.row]
            } else {
                walletDigests[indexPath.row]
            }
            let hasSecret = switch digest.wallet {
            case .privacy:
                false
            case .common(let wallet):
                secretAvailableWalletIDs.contains(wallet.walletID)
            }
            cell.load(digest: digest, hasSecret: hasSecret)
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

extension ReceivingWalletSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let digest = if let searchResults {
            searchResults[indexPath.row]
        } else {
            walletDigests[indexPath.row]
        }
        let uncontrolledWallet: Web3Wallet?
        switch digest.wallet {
        case .privacy:
            uncontrolledWallet = nil
        case .common(let wallet):
            switch wallet.category.knownCase {
            case .classic:
                uncontrolledWallet = nil
            case .importedMnemonic:
                if AppGroupKeychain.importedMnemonics(walletID: wallet.walletID) == nil {
                    uncontrolledWallet = wallet
                } else {
                    uncontrolledWallet = nil
                }
            case .importedPrivateKey:
                if AppGroupKeychain.importedPrivateKey(walletID: wallet.walletID) == nil {
                    uncontrolledWallet = wallet
                } else {
                    uncontrolledWallet = nil
                }
            case .watchAddress, .none:
                uncontrolledWallet = wallet
            }
        }
        if let wallet = uncontrolledWallet {
            let warning = UncontrolledWalletWarningViewController(wallet: wallet)
            warning.onConfirm = { [weak self] in
                guard let self else {
                    return
                }
                self.presentingViewController?.dismiss(animated: true) {
                    self.delegate?.receivingWalletSelectorViewController(self, didSelectWallet: digest.wallet)
                }
            }
            present(warning, animated: true)
        } else {
            presentingViewController?.dismiss(animated: true) {
                self.delegate?.receivingWalletSelectorViewController(self, didSelectWallet: digest.wallet)
            }
        }
    }
    
}
