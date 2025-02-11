import UIKit
import MixinServices

protocol TokenSelectorViewControllerDelegate: AnyObject {
    func tokenSelectorViewController(_ viewController: LegacyTokenSelectorViewController, didSelectToken token: TokenItem)
}

final class LegacyTokenSelectorViewController: PopupSearchableTableViewController {
    
    weak var delegate: TokenSelectorViewControllerDelegate?
    
    var tokens = [TokenItem]()
    var token: TokenItem?
    
    private var searchResults = [TokenItem]()
    
    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        if let assetId = token?.assetID, let index = tokens.firstIndex(where: { $0.assetID == assetId }) {
            var reordered = tokens
            let selected = reordered.remove(at: index)
            reordered.insert(selected, at: 0)
            self.tokens = reordered
        }
        tableView.register(R.nib.compactAssetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = tokens.filter({ (asset) -> Bool in
            asset.symbol.lowercased().contains(keyword)
                || asset.name.lowercased().contains(keyword)
        })
    }
    
}

extension LegacyTokenSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let token = isSearching ? searchResults[indexPath.row] : tokens[indexPath.row]
        let isSelected = token.assetID == self.token?.assetID
        cell.render(token: token, isSelected: isSelected)
        return cell
    }
    
}

extension LegacyTokenSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = isSearching ? searchResults[indexPath.row] : tokens[indexPath.row]
        delegate?.tokenSelectorViewController(self, didSelectToken: token)
        dismiss(animated: true, completion: nil)
    }
    
}
