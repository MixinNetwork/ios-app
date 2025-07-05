import UIKit
import MixinServices

final class AddWalletSelectorViewController: UIViewController {
    
    @IBOutlet weak var importButtonWrapperView: UIView!
    @IBOutlet weak var importButton: UIButton!
    
    private let mnemonics: BIP39Mnemonics
    
    private var candidates: [WalletCandidate]
    private var lastIndex: UInt32
    private var isSearching = false {
        didSet {
            footerView?.isBusy = isSearching
        }
    }
    
    private weak var collectionView: UICollectionView!
    private weak var headerView: HeaderView?
    private weak var footerView: FooterView?
    
    private var collectionViewSelectedCount: Int {
        collectionView.indexPathsForSelectedItems?.count ?? 0
    }
    
    init(mnemonics: BIP39Mnemonics, candidates: [WalletCandidate], lastIndex: UInt32) {
        self.mnemonics = mnemonics
        self.candidates = candidates
        self.lastIndex = lastIndex
        let nib = R.nib.addWalletSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.localizable.import_wallets()
        let layout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(112))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(112))
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
            group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: .fixed(5))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            return section
        }
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(45)
            ),
            elementKind: ElementKind.globalHeader,
            alignment: .top
        )
        header.pinToVisibleBounds = true
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(46)
            ),
            elementKind: ElementKind.globalFooter,
            alignment: .bottom
        )
        layout.configuration = {
            let config = UICollectionViewCompositionalLayoutConfiguration()
            config.interSectionSpacing = 0
            config.boundarySupplementaryItems = [header, footer]
            return config
        }()
        
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(importButtonWrapperView.snp.top)
        }
        self.collectionView = collectionView
        collectionView.register(R.nib.addWalletCandidateCell)
        collectionView.register(
            HeaderView.self,
            forSupplementaryViewOfKind: ElementKind.globalHeader,
            withReuseIdentifier: ReuseIdentifier.header
        )
        collectionView.register(
            FooterView.self,
            forSupplementaryViewOfKind: ElementKind.globalFooter,
            withReuseIdentifier: ReuseIdentifier.footer
        )
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
        if !candidates.isEmpty {
            let first = IndexPath(item: 0, section: 0)
            collectionView.selectItem(at: first, animated: false, scrollPosition: [])
        }
    }
    
    @IBAction func importSelectedWallets(_ sender: Any) {
        
    }
    
    private func selectAllCandidates() {
        for item in 0..<candidates.count {
            let indexPath = IndexPath(item: item, section: 0)
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        headerView?.selectedCount = collectionViewSelectedCount
        importButton.isEnabled = collectionViewSelectedCount != 0
    }
    
    private func showError(_ description: String) {
        isSearching = false
        showAutoHiddenHud(style: .error, text: description)
    }
    
    private func findMoreWallets() {
        isSearching = true
        DispatchQueue.global().async { [mnemonics, lastIndex, weak self] in
            let indices = (lastIndex + 1)...(lastIndex + 10)
            let wallets: [BIP39Mnemonics.DerivedWallet]
            do {
                wallets = try mnemonics.deriveWallets(indices: indices)
            } catch {
                DispatchQueue.main.async {
                    self?.showError(error.localizedDescription)
                }
                return
            }
            let addresses = wallets.flatMap { wallet in
                [wallet.evm.address, wallet.solana.address]
            }
            RouteAPI.assets(searchAddresses: addresses, queue: .global()) { result in
                switch result {
                case let .success(assets):
                    let tokens = assets.reduce(into: [:]) { result, addressAssets in
                        result[addressAssets.address] = addressAssets.assets
                    }
                    let candidates: [WalletCandidate] = wallets.compactMap { wallet in
                        let evmTokens = tokens[wallet.evm.address] ?? []
                        let solanaTokens = tokens[wallet.solana.address] ?? []
                        let tokens = evmTokens + solanaTokens
                        return tokens.isEmpty ? nil : WalletCandidate(
                            evmWallet: wallet.evm,
                            solanaWallet: wallet.solana,
                            tokens: tokens
                        )
                    }
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        self.isSearching = false
                        self.lastIndex = indices.upperBound
                        if !candidates.isEmpty {
                            let newItems = (self.candidates.count..<self.candidates.count + candidates.count)
                            let newIndexPaths = newItems.map { item in
                                IndexPath(item: item, section: 0)
                            }
                            self.candidates.append(contentsOf: candidates)
                            self.collectionView.insertItems(at: newIndexPaths)
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self?.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
}

extension AddWalletSelectorViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AddWalletSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        candidates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.add_wallet_candidate, for: indexPath)!
        cell.load(candidate: candidates[indexPath.item], index: indexPath.item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case ElementKind.globalHeader:
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ReuseIdentifier.header,
                for: indexPath
            ) as! HeaderView
            header.selectedCount = collectionViewSelectedCount
            header.onSelectAll = { [weak self] in
                self?.selectAllCandidates()
            }
            self.headerView = header
            return header
        case ElementKind.globalFooter:
            let footer = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ReuseIdentifier.footer,
                for: indexPath
            ) as! FooterView
            footer.onFindMore = { [weak self] in
                self?.findMoreWallets()
            }
            footer.isBusy = isSearching
            self.footerView = footer
            return footer
        default:
            return UICollectionReusableView()
        }
    }
    
}

extension AddWalletSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        headerView?.selectedCount = collectionViewSelectedCount
        importButton.isEnabled = true
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        headerView?.selectedCount = collectionViewSelectedCount
        importButton.isEnabled = collectionViewSelectedCount != 0
    }
    
}

extension AddWalletSelectorViewController {
    
    private enum ElementKind {
        static let globalHeader = "GlobalHeader"
        static let globalFooter = "GlobalFooter"
    }
    
    private enum ReuseIdentifier {
        static let header = "h"
        static let footer = "f"
    }
    
    private final class HeaderView: UICollectionReusableView {
        
        weak var titleLabel: UILabel!
        weak var selectAllButton: UIButton!
        
        var onSelectAll: (() -> Void)?
        var selectedCount: Int = 0 {
            didSet {
                switch selectedCount {
                case 0:
                    titleLabel.alpha = 0
                case 1:
                    titleLabel.alpha = 1
                    titleLabel.text = R.string.localizable.selected_wallet_count_one()
                default:
                    titleLabel.alpha = 1
                    titleLabel.text = R.string.localizable.selected_wallet_count(selectedCount)
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        @objc private func selectAllWallets(_ sender: Any) {
            onSelectAll?()
        }
        
        private func loadSubviews() {
            backgroundColor = R.color.background_secondary()
            let titleLabel = UILabel()
            titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            titleLabel.setFont(
                scaledFor: .systemFont(ofSize: 14),
                adjustForContentSize: true
            )
            titleLabel.textColor = R.color.text_secondary()
            let selectAllButton = UIButton(type: .system)
            selectAllButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            selectAllButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            selectAllButton.configuration = {
                var config: UIButton.Configuration = .plain()
                config.baseForegroundColor = R.color.theme()
                config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
                config.title = R.string.localizable.select_all()
                config.titleTextAttributesTransformer = .init { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    )
                    return outgoing
                }
                return config
            }()
            selectAllButton.titleLabel?.adjustsFontForContentSizeCategory = true
            selectAllButton.addTarget(
                self,
                action: #selector(selectAllWallets(_:)),
                for: .touchUpInside
            )
            let stackView = UIStackView(arrangedSubviews: [titleLabel, selectAllButton])
            stackView.spacing = 8
            stackView.axis = .horizontal
            stackView.alignment = .center
            addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(8)
                make.leading.equalToSuperview().offset(28)
                make.trailing.equalToSuperview().offset(-8)
                make.bottom.equalToSuperview()
            }
            self.titleLabel = titleLabel
            self.selectAllButton = selectAllButton
        }
        
    }
    
    private final class FooterView: UICollectionReusableView {
        
        var onFindMore: (() -> Void)?
        var isBusy = false {
            didSet {
                if isBusy {
                    busyIndicator.startAnimating()
                    findMoreButton.isHidden = true
                } else {
                    busyIndicator.stopAnimating()
                    findMoreButton.isHidden = false
                }
            }
        }
        
        private weak var findMoreButton: UIButton!
        private weak var busyIndicator: ActivityIndicatorView!
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        @objc private func callForMore(_ sender: Any) {
            onFindMore?()
        }
        
        private func loadSubviews() {
            let findMoreButton = UIButton(type: .system)
            findMoreButton.configuration = {
                var config: UIButton.Configuration = .plain()
                config.baseForegroundColor = R.color.theme()
                config.title = R.string.localizable.find_more_wallets()
                config.titleTextAttributesTransformer = .init { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14, weight: .medium)
                    )
                    return outgoing
                }
                return config
            }()
            findMoreButton.titleLabel?.adjustsFontForContentSizeCategory = true
            findMoreButton.addTarget(
                self,
                action: #selector(callForMore(_:)),
                for: .touchUpInside
            )
            addSubview(findMoreButton)
            findMoreButton.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.top.equalToSuperview().offset(10)
                make.bottom.equalToSuperview().offset(-13)
            }
            self.findMoreButton = findMoreButton
            
            let busyIndicator = ActivityIndicatorView()
            busyIndicator.tintColor = R.color.text_tertiary()!
            addSubview(busyIndicator)
            busyIndicator.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            busyIndicator.isAnimating = false
            self.busyIndicator = busyIndicator
        }
        
    }
    
}
