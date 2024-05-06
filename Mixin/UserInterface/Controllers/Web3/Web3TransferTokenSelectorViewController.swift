import UIKit
import MixinServices

protocol Web3TransferTokenSelectorViewControllerDelegate: AnyObject {
    func web3TransferTokenSelectorViewController(_ viewController: Web3TransferTokenSelectorViewController, didSelectToken token: TokenItem)
    func web3TransferTokenSelectorViewController(_ viewController: Web3TransferTokenSelectorViewController, didSelectToken token: Web3Token)
}

final class Web3TransferTokenSelectorViewController: PopupSearchableTableViewController {
    
    weak var delegate: Web3TransferTokenSelectorViewControllerDelegate?
    
    private var allTokens: [Web3TransferableToken] = []
    private var searchResults: [Web3TransferableToken] = []
    
    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        tableView.register(R.nib.compactAssetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = allTokens.filter { token in
            token.symbol.lowercased().contains(keyword)
            || token.name.lowercased().contains(keyword)
        }
    }
    
    func reload(tokens: [Web3TransferableToken]) {
        self.allTokens = tokens
        if isViewLoaded {
            tableView.reloadData()
        }
    }
    
}

extension Web3TransferTokenSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isSearching ? searchResults.count : allTokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let token = isSearching ? searchResults[indexPath.row] : allTokens[indexPath.row]
        switch token {
        case let token as TokenItem:
            cell.render(token: token, style: .nameWithBalance)
        case let token as Web3Token:
            cell.render(web3Token: token)
        default:
            break
        }
        return cell
    }
    
}

extension Web3TransferTokenSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = isSearching ? searchResults[indexPath.row] : allTokens[indexPath.row]
        switch token {
        case let token as TokenItem:
            delegate?.web3TransferTokenSelectorViewController(self, didSelectToken: token)
        case let token as Web3Token:
            delegate?.web3TransferTokenSelectorViewController(self, didSelectToken: token)
        default:
            break
        }
        dismiss(animated: true, completion: nil)
    }
    
}
