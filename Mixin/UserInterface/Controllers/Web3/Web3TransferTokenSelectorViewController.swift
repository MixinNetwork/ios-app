import UIKit
import MixinServices

final class Web3TransferTokenSelectorViewController<Token: Web3TransferableToken>: PopupSearchableTableViewController, UITableViewDataSource, UITableViewDelegate {
    
    var onSelected: ((Token) -> Void)?
    
    private var allTokens: [Token] = []
    private var searchResults: [Token] = []
    
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
    
    func reload(tokens: [Token]) {
        self.allTokens = tokens
        if isViewLoaded {
            tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource
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
        case let token as SwappableToken:
            cell.render(swappableToken: token)
        case let token as BalancedSwappableToken:
            cell.render(swappableToken: token.token, balance: token.decimalBalance, usdPrice: token.decimalUSDPrice)
        default:
            break
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = isSearching ? searchResults[indexPath.row] : allTokens[indexPath.row]
        onSelected?(token)
        dismiss(animated: true, completion: nil)
    }
    
}
