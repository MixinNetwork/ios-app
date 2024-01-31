import UIKit
import MixinServices

protocol LegacyTransferTypeViewControllerDelegate: AnyObject {
    func transferTypeViewController(_ viewController: LegacyTransferTypeViewController, didSelectAsset asset: AssetItem)
}

class LegacyTransferTypeViewController: PopupSearchableTableViewController {
    
    weak var delegate: LegacyTransferTypeViewControllerDelegate?
    
    var assets = [AssetItem]()
    var asset: AssetItem?
    
    private var searchResults = [AssetItem]()
    
    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        if let assetId = asset?.assetId, let index = assets.firstIndex(where: { $0.assetId == assetId }) {
            var reordered = assets
            let selected = reordered.remove(at: index)
            reordered.insert(selected, at: 0)
            self.assets = reordered
        }
        tableView.register(R.nib.transferTypeCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = assets.filter({ (asset) -> Bool in
            asset.symbol.lowercased().contains(keyword)
                || asset.name.lowercased().contains(keyword)
        })
    }
    
}

extension LegacyTransferTypeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.transfer_type, for: indexPath)!
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        cell.checkmarkView.isHidden = !(asset.assetId == self.asset?.assetId)
        cell.render(asset: asset)
        return cell
    }
    
}

extension LegacyTransferTypeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        delegate?.transferTypeViewController(self, didSelectAsset: asset)
        dismiss(animated: true, completion: nil)
    }
    
}
