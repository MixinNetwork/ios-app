import UIKit
import OrderedCollections
import MixinServices

final class WatchWalletAddressesViewController: UIViewController {
    
    private let addresses: OrderedDictionary<Web3Chain.Kind, String>
    
    private weak var collectionView: UICollectionView!
    
    init(addresses: OrderedDictionary<Web3Chain.Kind, String>) {
        self.addresses = addresses
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, _) in
            switch Section(rawValue: sectionIndex)! {
            case .introduction:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(238))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(238))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
                return section
            case .address:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(85))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(85))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                section.boundarySupplementaryItems = [
                    NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(43)),
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
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        collectionView.register(R.nib.watchWalletAddressesIntroductionCell)
        collectionView.register(R.nib.watchWalletAddressCell)
        collectionView.register(
            HeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ReuseIdentifier.header
        )
        collectionView.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: ReuseIdentifier.footer
        )
        self.collectionView = collectionView
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.dataSource = self
        collectionView.reloadData()
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}

extension WatchWalletAddressesViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension WatchWalletAddressesViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .introduction:
            1
        case .address:
            addresses.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .introduction:
            return collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watch_wallet_addresses_introduction, for: indexPath)!
        case .address:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.watch_wallet_address, for: indexPath)!
            let (kind, address) = addresses.elements[indexPath.item]
            cell.addressLabel.text = address
            cell.chainImageView.image = switch kind {
            case .bitcoin:
                R.image.bitcoin_chain()
            case .evm:
                R.image.evm_chains()
            case .solana:
                R.image.solana_chain()
            }
            cell.delegate = self
            return cell
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            return collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ReuseIdentifier.header,
                for: indexPath
            )
        case UICollectionView.elementKindSectionFooter:
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: ReuseIdentifier.footer,
                for: indexPath
            )
            view.backgroundColor = R.color.background()
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
            view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            return view
        default:
            return UICollectionReusableView()
        }
    }
    
}

extension WatchWalletAddressesViewController: WatchWalletAddressCell.Delegate {
    
    func watchWalletAddressCellDidSelectCopy(_ cell: WatchWalletAddressCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        UIPasteboard.general.string = addresses.elements[indexPath.item].value
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension WatchWalletAddressesViewController {
    
    private enum Section: Int, CaseIterable {
        case introduction
        case address
    }
    
    private enum ReuseIdentifier {
        static let header = "h"
        static let footer = "f"
    }
    
    private final class HeaderView: UICollectionReusableView {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadLabel()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadLabel()
        }
        
        private func loadLabel() {
            backgroundColor = R.color.background()
            layer.cornerRadius = 8
            layer.masksToBounds = true
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            let label = UILabel()
            addSubview(label)
            label.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(20)
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.equalToSuperview().offset(-6)
            }
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            label.textColor = R.color.text_quaternary()
            label.text = R.string.localizable.addresses().uppercased()
        }
        
    }
    
}
