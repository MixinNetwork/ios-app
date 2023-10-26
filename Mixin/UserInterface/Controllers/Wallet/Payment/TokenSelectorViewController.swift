import UIKit
import MixinServices

protocol TokenSelectorViewControllerDelegate: AnyObject {
    func tokenSelectorViewController(_ viewController: TokenSelectorViewController, didSelectToken token: TokenItem)
}

class TokenSelectorViewController: PopupSearchableTableViewController {
    
    weak var delegate: TokenSelectorViewControllerDelegate?
    
    var tokens = [TokenItem]()
    var token: TokenItem?
    
    private var searchResults = [TokenItem]()
    
    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        if let assetId = token?.assetId, let index = tokens.firstIndex(where: { $0.assetId == assetId }) {
            var reordered = tokens
            let selected = reordered.remove(at: index)
            reordered.insert(selected, at: 0)
            self.tokens = reordered
        }
        tableView.register(R.nib.transferTypeCell)
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

extension TokenSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.transfer_type, for: indexPath)!
        let token = isSearching ? searchResults[indexPath.row] : tokens[indexPath.row]
        cell.checkmarkView.isHidden = !(token.assetId == self.token?.assetId)
        cell.render(token: token)
        return cell
    }
    
}

extension TokenSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = isSearching ? searchResults[indexPath.row] : tokens[indexPath.row]
        delegate?.tokenSelectorViewController(self, didSelectToken: token)
        dismiss(animated: true, completion: nil)
    }
    
}
