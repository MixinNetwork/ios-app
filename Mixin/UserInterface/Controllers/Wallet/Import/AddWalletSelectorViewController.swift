import UIKit
import MixinServices

final class AddWalletSelectorViewController: UIViewController {
    
    @IBOutlet weak var importButtonWrapperView: UIView!
    @IBOutlet weak var importButton: UIButton!
    
    private let mnemonics: BIP39Mnemonics
    private let encryptedMnemonics: EncryptedBIP39Mnemonics
    private let firstNameIndex: Int
    private let searchWalletDerivationsCount: UInt32 = 10
    
    private var candidates: [WalletCandidate]
    private var nameIndices: [Int: Int] // Key is candidateIndex, value is nameIndex
    private var lastPathIndex: UInt32
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
    
    private var hasSelectedAllWallets: Bool {
        let selectableCandidatesCount = candidates.count(where: \.isImportable)
        return selectableCandidatesCount != 0
        && collectionViewSelectedCount == selectableCandidatesCount
    }
    
    init(
        mnemonics: BIP39Mnemonics,
        encryptedMnemonics: EncryptedBIP39Mnemonics,
        candidates: [WalletCandidate],
        lastPathIndex: UInt32,
        firstNameIndex: Int
    ) {
        self.mnemonics = mnemonics
        self.encryptedMnemonics = encryptedMnemonics
        self.candidates = candidates
        self.nameIndices = Self.nameIndices(candidates: candidates, firstNameIndex: firstNameIndex)
        self.lastPathIndex = lastPathIndex
        self.firstNameIndex = firstNameIndex
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
            group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: nil)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 13, trailing: 20)
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
        for item in candidates.indices {
            let indexPath = IndexPath(item: item, section: 0)
            guard self.collectionView(collectionView, shouldSelectItemAt: indexPath) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        
        importButton.configuration?.titleTextAttributesTransformer = .init { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            return outgoing
        }
        updateViewsWithSelectionCount()
        importButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func importSelectedWallets(_ sender: Any) {
        let indices = collectionView.indexPathsForSelectedItems?.map(\.item).sorted(by: <)
        guard let indices, !indices.isEmpty else {
            return
        }
        let namedWallets = indices.map { index in
            NamedWalletCandidate(
                name: R.string.localizable.common_wallet_index("\(nameIndices[index] ?? 0)"),
                candidate: candidates[index]
            )
        }
        let importing = AddWalletImportingViewController(
            importingWallet: .byMnemonics(mnemonics: encryptedMnemonics, wallets: namedWallets)
        )
        navigationController?.pushViewController(importing, animated: true)
    }
    
    private func updateViewsWithSelectionCount() {
        let count = self.collectionViewSelectedCount
        if let headerView {
            headerView.selectedCount = count
            headerView.action = hasSelectedAllWallets ? .deselectAll : .selectAll
        }
        importButton.isEnabled = count != 0
        importButton.configuration?.title = switch count {
        case 0:
            R.string.localizable.import_selected_wallet()
        case 1:
            R.string.localizable.import_wallet_count_one()
        default:
            R.string.localizable.import_wallet_count(count)
        }
    }
    
    private func selectAllCandidates() {
        for item in candidates.indices {
            let indexPath = IndexPath(item: item, section: 0)
            guard self.collectionView(collectionView, shouldSelectItemAt: indexPath) else {
                continue
            }
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        updateViewsWithSelectionCount()
    }
    
    private func deselectAllCandidates() {
        guard let indexPaths = collectionView.indexPathsForSelectedItems else {
            return
        }
        for indexPath in indexPaths {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
        updateViewsWithSelectionCount()
    }
    
    private func showError(_ description: String) {
        isSearching = false
        showAutoHiddenHud(style: .error, text: description)
    }
    
    private func findMoreWallets() {
        isSearching = true
        let indices = (lastPathIndex + 1)...(lastPathIndex + searchWalletDerivationsCount)
        DispatchQueue.global().async { [mnemonics, weak self] in
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
                    let walletNames = Web3WalletDAO.shared.walletNames()
                    let tokens = assets.reduce(into: [:]) { result, addressAssets in
                        result[addressAssets.address] = addressAssets.assets
                    }
                    let newCandidates: [WalletCandidate] = wallets.compactMap { wallet in
                        let bitcoinTokens = tokens[wallet.bitcoin.address] ?? []
                        let evmTokens = tokens[wallet.evm.address] ?? []
                        let solanaTokens = tokens[wallet.solana.address] ?? []
                        
                        let name = walletNames[wallet.bitcoin.address]
                        ?? walletNames[wallet.evm.address]
                        ?? walletNames[wallet.solana.address]
                        
                        return tokens.isEmpty ? nil : WalletCandidate(
                            bitcoinWallet: wallet.bitcoin,
                            evmWallet: wallet.evm,
                            solanaWallet: wallet.solana,
                            tokens: bitcoinTokens + evmTokens + solanaTokens,
                            importedAsName: name
                        )
                    }
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        self.isSearching = false
                        self.lastPathIndex = indices.upperBound
                        if !newCandidates.isEmpty {
                            let newItems = (self.candidates.count..<self.candidates.count + newCandidates.count)
                            let newIndexPaths = newItems.map { item in
                                IndexPath(item: item, section: 0)
                            }
                            self.candidates.append(contentsOf: newCandidates)
                            self.nameIndices = Self.nameIndices(candidates: self.candidates, firstNameIndex: self.firstNameIndex)
                            self.collectionView.insertItems(at: newIndexPaths)
                            for indexPath in newIndexPaths {
                                guard self.collectionView(self.collectionView, shouldSelectItemAt: indexPath) else {
                                    continue
                                }
                                self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                            }
                            self.updateViewsWithSelectionCount()
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
        cell.load(candidate: candidates[indexPath.item], index: nameIndices[indexPath.item] ?? 0)
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
            header.action = hasSelectedAllWallets ? .deselectAll : .selectAll
            header.onSelectionUpdate = { [weak self] (action) in
                switch action {
                case .selectAll:
                    self?.selectAllCandidates()
                case .deselectAll:
                    self?.deselectAllCandidates()
                }
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
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        candidates[indexPath.item].isImportable
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateViewsWithSelectionCount()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        updateViewsWithSelectionCount()
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
        
        enum SelectionAction {
            case selectAll
            case deselectAll
        }
        
        weak var titleLabel: UILabel!
        weak var updateSelectionButton: UIButton!
        
        var onSelectionUpdate: ((SelectionAction) -> Void)?
        
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
        
        var action: SelectionAction = .deselectAll {
            didSet {
                updateSelectionButton.configuration?.title = switch action {
                case .selectAll:
                    R.string.localizable.select_all()
                case .deselectAll:
                    R.string.localizable.deselect_all()
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
        
        @objc private func updateSelection(_ sender: Any) {
            onSelectionUpdate?(action)
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
            let updateSelectionButton = UIButton(type: .system)
            updateSelectionButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            updateSelectionButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            updateSelectionButton.configuration = {
                var config: UIButton.Configuration = .plain()
                config.baseForegroundColor = R.color.theme()
                config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
                config.title = R.string.localizable.deselect_all()
                config.titleTextAttributesTransformer = .init { incoming in
                    var outgoing = incoming
                    outgoing.font = UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    )
                    return outgoing
                }
                return config
            }()
            updateSelectionButton.titleLabel?.adjustsFontForContentSizeCategory = true
            updateSelectionButton.addTarget(
                self,
                action: #selector(updateSelection(_:)),
                for: .touchUpInside
            )
            let stackView = UIStackView(arrangedSubviews: [titleLabel, updateSelectionButton])
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
            self.updateSelectionButton = updateSelectionButton
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
                make.centerX.equalToSuperview()
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
    
    private static func nameIndices(candidates: [WalletCandidate], firstNameIndex: Int) -> [Int: Int] {
        var nextNameIndex = firstNameIndex
        return candidates.indices.reduce(into: [:]) { result, index in
            guard candidates[index].isImportable else {
                return
            }
            result[index] = nextNameIndex
            nextNameIndex += 1
        }
    }
    
}
