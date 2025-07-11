import UIKit
import Combine
import MixinServices

final class ReceivingWalletSelectorViewController: UIViewController {
    
    protocol Delegate: AnyObject {
        func receivingWalletSelectorViewController(_ viewController: ReceivingWalletSelectorViewController, didSelectWallet wallet: Wallet)
    }
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var delegate: Delegate?
    
    private var excludingWallet: Wallet
    private var walletDigests: [WalletDigest] = []
    private var searchObserver: AnyCancellable?
    private var searchingKeyword: String?
    private var searchResults: [WalletDigest]?
    
    init(excluding wallet: Wallet) {
        self.excludingWallet = wallet
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
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(122))
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
            group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: nil, trailing: nil, bottom: .fixed(5))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
            return section
        }
        collectionView.allowsMultipleSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        DispatchQueue.global().async { [excludingWallet] in
            let digests: [WalletDigest]
            switch excludingWallet {
            case .privacy:
                digests = Web3WalletDAO.shared.walletDigests()
            case .common:
                let commonWallets = Web3WalletDAO.shared.walletDigests().filter { digest in
                    digest.wallet != excludingWallet
                }
                digests = [TokenDAO.shared.walletDigest()] + commonWallets
            }
            DispatchQueue.main.async {
                self.walletDigests = digests
                self.collectionView.reloadData()
            }
        }
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
    
    private func search(keyword: String) {
        searchingKeyword = keyword
        searchResults = walletDigests.filter { digest in
            digest.wallet.localizedName.lowercased().contains(keyword)
        }
        collectionView.reloadData()
        searchBoxView.isBusy = false
    }
    
}

extension ReceivingWalletSelectorViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let searchResults {
            searchResults.count
        } else {
            walletDigests.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.wallet, for: indexPath)!
        let digest = if let searchResults {
            searchResults[indexPath.row]
        } else {
            walletDigests[indexPath.row]
        }
        cell.load(digest: digest)
        return cell
    }
    
}

extension ReceivingWalletSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let digest = if let searchResults {
            searchResults[indexPath.row]
        } else {
            walletDigests[indexPath.row]
        }
        presentingViewController?.dismiss(animated: true) {
            self.delegate?.receivingWalletSelectorViewController(self, didSelectWallet: digest.wallet)
        }
    }
    
}
