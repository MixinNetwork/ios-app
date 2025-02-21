import UIKit
import MixinServices

final class WalletSummaryViewController: UIViewController {
    
    enum Section: Int, CaseIterable {
        case value
        case wallets
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var privacyWalletDigest: WalletDigest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(R.nib.walletSummaryValueCell)
        collectionView.register(R.nib.walletCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (sectionIndex, environment) in
            switch Section(rawValue: sectionIndex)! {
            case .value:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(15)),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .bottom
                    )
                ]
                return section
            case .wallets:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(112))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
                return section
            }
        }
        collectionView.allowsMultipleSelection = true
        collectionView.dataSource = self
        collectionView.delegate = self
        NotificationCenter.default.addObserver(
            collectionView!,
            selector: #selector(collectionView.reloadData),
            name: Currency.currentCurrencyDidChangeNotification,
            object: nil
        )
        DispatchQueue.global().async {
            let digest = TokenDAO.shared.walletDigest()
            DispatchQueue.main.async {
                self.privacyWalletDigest = digest
                self.collectionView.reloadData()
            }
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .value:
            1
        case .wallets:
            1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .value:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet_summary_value, for: indexPath)!
            if let digest = privacyWalletDigest {
                cell.load(digest: digest)
            }
            return cell
        case .wallets:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
            switch indexPath.row {
            case 0:
                if let digest = privacyWalletDigest {
                    cell.load(digest: digest, type: .privacy)
                }
            default:
                break
            }
            return cell
        }
    }
    
}

extension WalletSummaryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .value:
            break
        case .wallets:
            if let parent = parent as? WalletContainerViewController {
                parent.switchToWallet()
            }
        }
    }
    
}
