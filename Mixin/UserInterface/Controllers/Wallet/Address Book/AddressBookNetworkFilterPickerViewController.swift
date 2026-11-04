import UIKit
import MixinServices

final class AddressBookNetworkFilterPickerViewController: TransactionHistoryFilterPickerViewController, UITableViewDelegate {
    
    var onApply: (([AddressBookNetwork]) -> Void)?
    
    private let selectedNetworkReuseIdentifier = "sn"
    private let networks: [AddressBookNetwork]
    
    private var selectedChainIDs: Set<String>
    private var selectedNetworks: [AddressBookNetwork]
    private var searchResults: [AddressBookNetwork] = []
    
    private var networkModels: [AddressBookNetwork] {
        isSearching ? searchResults : networks
    }
    
    init(networks: [AddressBookNetwork], selectedNetworks: [AddressBookNetwork]) {
        self.networks = networks
        self.selectedChainIDs = Set(selectedNetworks.map(\.chainID))
        self.selectedNetworks = selectedNetworks
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.name()
        hideSegmentControlWrapperView()
        tableView.register(R.nib.checkmarkTokenCell)
        tableView.dataSource = self
        tableView.delegate = self
        collectionView.register(SelectedTokenCell.self, forCellWithReuseIdentifier: selectedNetworkReuseIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        collectionView.dataSource = self
        tableView.reloadData()
        reloadTableViewSelections()
        if !selectedChainIDs.isEmpty {
            showSelections(animated: false)
        }
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        onApply?([])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        onApply?(selectedNetworks)
    }
    
    override func search(keyword: String) {
        searchingKeyword = keyword
        searchResults = networks.filter { $0.name.lowercased().contains(keyword) }
        tableView.reloadData()
        reloadTableViewSelections()
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        for (row, network) in networkModels.enumerated() where selectedChainIDs.contains(network.chainID) {
            tableView.selectRow(at: IndexPath(row: row, section: 0), animated: false, scrollPosition: .none)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let network = networkModels[indexPath.row]
        let (inserted, _) = selectedChainIDs.insert(network.chainID)
        if inserted {
            let indexPath = IndexPath(item: selectedNetworks.count, section: 0)
            selectedNetworks.append(network)
            collectionView.insertItems(at: [indexPath])
        }
        showSelections(animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let network = networkModels[indexPath.row]
        selectedChainIDs.remove(network.chainID)
        if let index = selectedNetworks.firstIndex(where: { $0.chainID == network.chainID }) {
            selectedNetworks.remove(at: index)
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        }
        if selectedChainIDs.isEmpty {
            hideSelections(animated: true)
        }
    }
    
}

extension AddressBookNetworkFilterPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        networkModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
        let network = networkModels[indexPath.row]
        if let chain = network.chain {
            cell.iconView.setIcon(chain: chain)
        } else {
            cell.iconView.prepareForReuse()
        }
        cell.titleLabel.text = network.name
        cell.tagLabel.isHidden = true
        cell.subtitleLabel.text = nil
        cell.subtitleLabel.isHidden = true
        return cell
    }
    
}

extension AddressBookNetworkFilterPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        selectedNetworks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: selectedNetworkReuseIdentifier, for: indexPath) as! SelectedTokenCell
        let network = selectedNetworks[indexPath.item]
        cell.load(network: network)
        cell.delegate = self
        return cell
    }
    
}

extension AddressBookNetworkFilterPickerViewController: SelectedItemCellDelegate {
    
    func selectedItemCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let deselected = selectedNetworks.remove(at: indexPath.item)
        selectedChainIDs.remove(deselected.chainID)
        collectionView.deleteItems(at: [indexPath])
        if let row = networkModels.firstIndex(where: { $0.chainID == deselected.chainID }) {
            tableView.deselectRow(at: IndexPath(row: row, section: 0), animated: true)
        }
        if selectedChainIDs.isEmpty {
            hideSelections(animated: true)
        }
    }
    
}
