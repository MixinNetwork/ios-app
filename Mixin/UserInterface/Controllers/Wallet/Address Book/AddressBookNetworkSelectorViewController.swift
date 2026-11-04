import UIKit
import SDWebImage
import MixinServices

final class AddressBookNetworkSelectorViewController: PopupSearchableTableViewController {
    
    var onSelect: ((AddressBookNetwork) -> Void)?
    
    private let networks: [AddressBookNetwork]
    private let selectedChainID: String?
    
    private var searchResults: [AddressBookNetwork] = []
    
    private var networkModels: [AddressBookNetwork] {
        isSearching ? searchResults : networks
    }
    
    init(networks: [AddressBookNetwork], selectedChainID: String?) {
        self.networks = networks
        self.selectedChainID = selectedChainID
        let nib = R.nib.popupSearchableTableView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.name()
        tableView.register(R.nib.currencyCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = networks.filter { network in
            network.name.lowercased().contains(keyword)
        }
    }
    
}

extension AddressBookNetworkSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        networkModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.currency, for: indexPath)!
        let network = networkModels[indexPath.row]
        cell.iconImageView.contentMode = .scaleAspectFit
        cell.iconImageView.layer.shadowOpacity = 0
        cell.iconImageView.layer.cornerRadius = 21
        cell.iconImageView.layer.masksToBounds = true
        cell.iconImageView.sd_cancelCurrentImageLoad()
        if let iconURL = network.chain?.iconUrl, let url = URL(string: iconURL) {
            cell.iconImageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
        } else {
            cell.iconImageView.image = R.image.unknown_session()
        }
        cell.codeLabel.text = network.name
        cell.checkmarkImageView.isHidden = network.chainID != selectedChainID
        return cell
    }
    
}

extension AddressBookNetworkSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(networkModels[indexPath.row])
    }
    
}
