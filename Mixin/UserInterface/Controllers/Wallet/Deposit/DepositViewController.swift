import UIKit
import MixinServices

final class DepositViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case network
        case address
        case info
    }
    
    private enum ReuseIdentifier {
        static let infosHeaderFooter = "e"
    }
    
    private weak var collectionView: UICollectionView!
    private weak var addressGeneratingView: UIView!
    private weak var depositSuspendedView: UIView?
    
    private var dataSource: DepositDataSource
    private var viewModel: DepositViewModel?
    
    convenience init(token: MixinTokenItem) {
        let dataSource = MixinDepositDataSource(token: token)
        self.init(dataSource: dataSource)
    }
    
    convenience init(wallet: Web3Wallet, token: Web3TokenItem) {
        let dataSource = Web3DepositDataSource(wallet: wallet, token: token)
        self.init(dataSource: dataSource)
    }
    
    init(dataSource: DepositDataSource) {
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.deposit()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.deposit_token(dataSource.symbol),
            wallet: dataSource.wallet
        )
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(contactSupport(_:))
        )
        view.backgroundColor = R.color.background_secondary()
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            switch Section(rawValue: sectionIndex)! {
            case .network:
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .estimated(37))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(37))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 12
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 15, bottom: 6, trailing: 15)
                return section
            case .address:
                let isNetworkSectionEmpty = self?.viewModel?.switchableTokens.isEmpty ?? true
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(489))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(489))
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                switch self?.viewModel?.entry {
                case .tagging:
                    section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                    let headerHeight: CGFloat = isNetworkSectionEmpty ? 26 : 20
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    )
                    let footer = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(78)),
                        elementKind: UICollectionView.elementKindSectionFooter,
                        alignment: .bottom
                    )
                    section.boundarySupplementaryItems = [header, footer]
                default:
                    let top: CGFloat = isNetworkSectionEmpty ? 16 : 10
                    section.contentInsets = NSDirectionalEdgeInsets(top: top, leading: 20, bottom: 10, trailing: 20)
                }
                return section
            case .info:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
                let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(10)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top
                    ),
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(10)),
                        elementKind: UICollectionView.elementKindSectionFooter,
                        alignment: .bottom
                    ),
                ]
                return section
            }
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.register(R.nib.exploreSegmentCell)
        collectionView.register(R.nib.depositGeneralEntryCell)
        collectionView.register(R.nib.depositTaggingEntryCell)
        collectionView.register(R.nib.depositInfoCell)
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ReuseIdentifier.infosHeaderFooter
        )
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: ReuseIdentifier.infosHeaderFooter
        )
        collectionView.register(
            R.nib.depositTaggingEntryHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.register(
            R.nib.depositTaggingEntryFooterView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isHidden = true
        self.collectionView = collectionView
        updateCollectionViewBottomInset()
        
        let addressGeneratingView = R.nib.depositAddressGeneratingView(withOwner: nil)!
        view.addSubview(addressGeneratingView)
        addressGeneratingView.snp.makeEdgesEqualToSuperview()
        self.addressGeneratingView = addressGeneratingView
        
        dataSource.delegate = self
        dataSource.reload()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewBottomInset()
    }
    
    @objc private func contactSupport(_ sender: Any) {
        guard let navigationController, let user = UserDAO.shared.getUser(identityNumber: "7000") else {
            return
        }
        let conversation = ConversationViewController.instance(ownerUser: user)
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(where: { $0 is HomeTabBarController }) {
            viewControllers.removeLast(viewControllers.count - index - 1)
        }
        viewControllers.append(conversation)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    private func updateCollectionViewBottomInset() {
        if view.safeAreaInsets.bottom < 10 {
            collectionView.contentInset.bottom = 10
        } else {
            collectionView.contentInset.bottom = 0
        }
    }
    
}

extension DepositViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension DepositViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel else {
            return 0
        }
        return switch Section(rawValue: section)! {
        case .network:
            viewModel.switchableTokens.count
        case .address:
            switch viewModel.entry {
            case .general:
                1
            case .tagging:
                2
            }
        case .info:
            viewModel.infos.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel else {
            return UICollectionViewCell()
        }
        switch Section(rawValue: indexPath.section)! {
        case .network:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
            cell.label.text = viewModel.switchableTokens[indexPath.item].chainName
            return cell
        case .address:
            switch viewModel.entry {
            case .general(let content, let supporting, let actions):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.deposit_general_entry, for: indexPath)!
                cell.load(content: content, token: viewModel.token, supporting: supporting, actions: actions)
                cell.delegate = self
                return cell
            case .tagging(let destination, let tag, _):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.deposit_tagging_entry, for: indexPath)!
                switch indexPath.item {
                case 0:
                    cell.load(content: tag, token: viewModel.token)
                default:
                    cell.load(content: destination, token: viewModel.token)
                }
                cell.delegate = self
                return cell
            }
        case .info:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.deposit_info, for: indexPath)!
            let info = viewModel.infos[indexPath.item]
            cell.titleLabel.text = info.title
            cell.contentLabel.text = info.description
            cell.infoButton.isHidden = !info.actions.contains(.presentInfo)
            cell.copyButton.isHidden = !info.actions.contains(.copyDescription)
            cell.delegate = self
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch Section(rawValue: indexPath.section)! {
        case .network:
            return UICollectionReusableView()
        case .address:
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: R.reuseIdentifier.deposit_tagging_entry_header,
                    for: indexPath
                )!
            case UICollectionView.elementKindSectionFooter:
                let view = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: R.reuseIdentifier.deposit_tagging_entry_footer,
                    for: indexPath
                )!
                switch viewModel?.entry {
                case let .tagging(_, _, supporting):
                    view.label.text = supporting
                default:
                    break
                }
                return view
            default:
                return UICollectionReusableView()
            }
        case .info:
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ReuseIdentifier.infosHeaderFooter,
                for: indexPath
            )
            view.backgroundColor = R.color.background()
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
            view.layer.maskedCorners = switch kind {
            case UICollectionView.elementKindSectionHeader:
                [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            case UICollectionView.elementKindSectionFooter:
                [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            default:
                []
            }
            return view
        }
    }
    
}

extension DepositViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .address, .info:
            return false
        case .network:
            let alreadySelected = collectionView.indexPathsForSelectedItems?.contains(indexPath) ?? false
            return !alreadySelected
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .address, .info:
            break
        case .network:
            guard let token = viewModel?.switchableTokens[indexPath.item] else {
                return
            }
            if let titleView = navigationItem.titleView as? WalletIdentifyingNavigationTitleView {
                titleView.titleLabel.text = R.string.localizable.deposit_token(token.symbol)
            }
            collectionView.isHidden = true
            addressGeneratingView.isHidden = false
            depositSuspendedView?.removeFromSuperview()
            dataSource.cancel()
            dataSource = dataSource.dataSource(bySwitchingTo: token)
            dataSource.delegate = self
            dataSource.reload()
        }
    }
    
}

extension DepositViewController: DepositEntryActionDelegate {
    
    func depositEntryCell(_ cell: UICollectionViewCell, didRequestAction action: DepositViewModel.Entry.Action) {
        guard let viewModel else {
            return
        }
        switch action {
        case .copy:
            guard let indexPath = collectionView.indexPath(for: cell) else {
                return
            }
            let copyingContent: String
            switch Section(rawValue: indexPath.section)! {
            case .network:
                return
            case .address:
                switch viewModel.entry {
                case let .general(content, _, _):
                    copyingContent = content.textValue
                case let .tagging(destination, tag, _):
                    switch indexPath.item {
                    case 0:
                        copyingContent = tag.textValue
                    default:
                        copyingContent = destination.textValue
                    }
                }
            case .info:
                copyingContent = viewModel.infos[indexPath.item].description
            }
            UIPasteboard.general.string = copyingContent
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        case .setAmount:
            guard let link = viewModel.link() else {
                return
            }
            let inputAmount = DepositInputAmountViewController(
                link: link,
                token: viewModel.token
            )
            let navigationController = GeneralAppearanceNavigationController(
                rootViewController: inputAmount
            )
            present(navigationController, animated: true)
        case .share:
            guard let link = viewModel.link() else {
                return
            }
            let share = ShareDepositLinkViewController(link: link)
            present(share, animated: true)
        }
    }
    
}

extension DepositViewController: DepositInfoCell.Delegate {
    
    func depositInfoCellDidRequestInfo(_ cell: DepositInfoCell) {
        guard
            let item = collectionView.indexPath(for: cell)?.item,
            let info = viewModel?.infos[item].presentableInfo
        else {
            return
        }
        let viewController = switch info {
        case .confirmations(let count):
            DepositConfirmationCountViewController(count: count)
        case .lightningAddress(let address):
            ExplainLightningAddressViewController(address: address)
        }
        present(viewController, animated: true)
    }
    
    func depositInfoCellDidRequestCopyDescription(_ cell: DepositInfoCell) {
        guard
            let item = collectionView.indexPath(for: cell)?.item,
            let description = viewModel?.infos[item].description
        else {
            return
        }
        UIPasteboard.general.string = description
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension DepositViewController: DepositDataSource.Delegate {
    
    func depositDataSource(
        _ dataSource: DepositDataSource,
        didUpdateViewModel viewModel: DepositViewModel,
        hint: WalletHintViewController?
    ) {
        self.viewModel = viewModel
        collectionView.isHidden = false
        collectionView.reloadData()
        if let item = viewModel.selectedTokenIndex {
            let indexPath = IndexPath(item: item, section: Section.network.rawValue)
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        }
        addressGeneratingView.isHidden = true
        depositSuspendedView?.removeFromSuperview()
        if let hint {
            hint.delegate = self
            present(hint, animated: true)
        }
    }
    
    func depositDataSource(
        _ dataSource: DepositDataSource,
        reportsDepositSuspendedWith suspendedView: DepositSuspendedView
    ) {
        addressGeneratingView.isHidden = true
        if suspendedView.superview == nil {
            view.addSubview(suspendedView)
            suspendedView.snp.makeEdgesEqualToSuperview()
            self.depositSuspendedView = suspendedView
        }
        suspendedView.contactSupportButton.removeTarget(
            self,
            action: nil,
            for: .touchUpInside
        )
        suspendedView.contactSupportButton.addTarget(
            self,
            action: #selector(contactSupport(_:)),
            for: .touchUpInside
        )
    }
    
}

extension DepositViewController: WalletHintViewControllerDelegate {
    
    func walletHintViewControllerDidRealize(_ controller: WalletHintViewController) {
        
    }
    
    func walletHintViewControllerWantsContactSupport(_ controller: WalletHintViewController) {
        contactSupport(controller)
    }
    
}
