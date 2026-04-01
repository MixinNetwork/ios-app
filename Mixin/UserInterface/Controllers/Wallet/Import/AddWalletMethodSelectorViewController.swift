import UIKit
import SafariServices
import MixinServices

final class AddWalletMethodSelectorViewController: UIViewController {
    
    private enum Section {
        case methods
        case freeTransfer
        case footer
    }
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var onSelected: ((AddWalletMethod) -> Void)?
    
    private var sections: [Section] = [.methods, .footer]
    
    init() {
        let nib = R.nib.addWalletMethodSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_quaternary()
        titleView.backgroundColor = R.color.background_quaternary()
        titleView.titleLabel.text = R.string.localizable.add_wallet()
        titleView.closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        collectionView.backgroundColor = R.color.background_quaternary()
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = true
        collectionView.register(R.nib.addWalletMethodCell)
        collectionView.register(R.nib.walletTipCell)
        collectionView.register(R.nib.addWalletFooterCell)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadTips(_:)),
            name: BadgeManager.viewedNotification,
            object: nil
        )
        if !BadgeManager.shared.hasViewed(identifier: .freeTransfer) {
            sections.insert(.freeTransfer, at: 1)
        }
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { [weak self] (sectionIndex, environment) in
            switch self?.sections[sectionIndex] {
            case .none, .methods:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 36, trailing: 16)
                section.interGroupSpacing = 10
                return section
            case .freeTransfer:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(146))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 32, trailing: 16)
                return section
            case .footer:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(213))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28)
                return section
            }
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func reloadTips(_ notification: Notification) {
        guard
            let identifier = notification.userInfo?[BadgeManager.identifierUserInfoKey],
            identifier as? BadgeManager.Identifier == .freeTransfer,
            let index = sections.firstIndex(of: .freeTransfer)
        else {
            return
        }
        sections.remove(at: index)
        let sections = IndexSet(integer: index)
        collectionView.deleteSections(sections)
    }
    
}

extension AddWalletMethodSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .methods:
            AddWalletMethod.allCases.count
        case .freeTransfer, .footer:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sections[indexPath.section] {
        case .methods:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.add_wallet_method, for: indexPath)!
            switch AddWalletMethod.allCases[indexPath.row] {
            case .create:
                cell.iconImageView.image = R.image.add_wallet_create()
                cell.titleLabel.text = R.string.localizable.create_new_wallet()
                cell.subtitleLabel.text = R.string.localizable.create_new_wallet_description()
            case .privateKey:
                cell.iconImageView.image = R.image.add_wallet_private_key()
                cell.titleLabel.text = R.string.localizable.import_private_key()
                cell.subtitleLabel.text = R.string.localizable.import_single_chain_wallet()
            case .mnemonics:
                cell.iconImageView.image = R.image.add_wallet_mnemonics()
                cell.titleLabel.text = R.string.localizable.import_mnemonic_phrase()
                cell.subtitleLabel.text = R.string.localizable.import_wallets_from_another_wallet()
            case .watch:
                cell.iconImageView.image = R.image.watching_wallet_large()
                cell.titleLabel.text = R.string.localizable.add_watch_address()
                cell.subtitleLabel.text = R.string.localizable.add_watch_address_description()
            }
            return cell
        case .freeTransfer:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_tip_cell, for: indexPath)!
            cell.delegate = self
            cell.content = .importedWalletSafety
            return cell
        case .footer:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.add_wallet_footer, for: indexPath)!
        }
    }
    
}

extension AddWalletMethodSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .methods:
            let method = AddWalletMethod.allCases[indexPath.row]
            presentingViewController?.dismiss(animated: true) { [onSelected] in
                onSelected?(method)
            }
        case .freeTransfer, .footer:
            break
        }
    }
    
}

extension AddWalletMethodSelectorViewController: WalletTipCell.Delegate {
    
    func walletTipCell(_ cell: WalletTipCell, requestToLearnMore url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
    
}
