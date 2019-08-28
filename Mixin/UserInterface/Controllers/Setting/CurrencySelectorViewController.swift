import UIKit

class CurrencySelectorViewController: PopupSearchableTableViewController {
    
    private let currencies = Currency.all
    
    private var searchResults = [Currency]()
    
    convenience init() {
        self.init(nib: R.nib.popupSearchableTableView)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_currency()
        tableView.register(R.nib.currencyCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = currencies.filter({ (currency) -> Bool in
            return currency.code.lowercased().contains(keyword)
        })
    }
    
}

extension CurrencySelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : currencies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.currency, for: indexPath)!
        
        let currency = isSearching ? searchResults[indexPath.row] : currencies[indexPath.row]
        cell.render(currency: currency)
        
        let isSelected = currency.code == Currency.current.code
        cell.checkmarkView.status = isSelected ? .selected : .unselected
        
        return cell
    }
    
}

extension CurrencySelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let currency = isSearching ? searchResults[indexPath.row] : currencies[indexPath.row]
        if Currency.current.code != currency.code {
            Currency.current = currency
        }
        dismiss(animated: true, completion: nil)
    }
    
}
