import UIKit
import MixinServices

final class ExportPrivateKeyNetworkSelectorViewController: UIViewController {
    
    private let wallet: Web3Wallet
    private let mnemonics: EncryptedBIP39Mnemonics
    
    private var networks: [Web3WalletNetwork] = []
    
    init(wallet: Web3Wallet, mnemonics: EncryptedBIP39Mnemonics) {
        self.wallet = wallet
        self.mnemonics = mnemonics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background_secondary()
        
        let titleView = PopupTitleView()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(70)
        }
        titleView.backgroundColor = R.color.background_secondary()
        titleView.titleLabel.text = R.string.localizable.choose_network()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        let layout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(64))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(64))
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
            group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(5), trailing: nil, bottom: .fixed(5))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)
            return section
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleView.snp.bottom)
        }
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.register(R.nib.importedWalletNetworkCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        DispatchQueue.global().async { [wallet, collectionView] in
            let networks = Web3AddressDAO.shared.networks(walletID: wallet.walletID)
            DispatchQueue.main.async {
                self.networks = networks
                collectionView.reloadData()
            }
        }
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}

extension ExportPrivateKeyNetworkSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        networks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.imported_wallet_network, for: indexPath)!
        let network = networks[indexPath.item]
        cell.iconView.setIcon(urlString: network.iconURL)
        cell.nameLabel.text = network.name
        cell.addressLabel.text = network.compactAddress
        return cell
    }
    
}

extension ExportPrivateKeyNetworkSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let network = networks[indexPath.item]
        guard let kind = Web3Chain.chain(chainID: network.chainID)?.kind else {
            return
        }
        do {
            let path = try DerivationPath(string: network.path)
            presentingViewController?.dismiss(animated: true) { [mnemonics] in
                let secret: ExportingSecret = .privateKeyFromMnemonics(mnemonics, kind, path)
                let introduction = ExportImportedSecretIntroductionViewController(secret: secret)
                UIApplication.homeNavigationController?.pushViewController(introduction, animated: true)
            }
        } catch {
            Logger.general.error(category: "ExportPrivateKey", message: "\(error)")
        }
    }
    
}
