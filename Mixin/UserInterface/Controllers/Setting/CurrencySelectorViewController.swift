import UIKit
import MixinServices

final class CurrencySelectorViewController: PopupSearchableTableViewController {
    
    private let currencies: [Currency]
    private let selectedCurrencyCode: String?
    private let onSelectedChange: (Currency) -> Void
    
    private var searchResults = [Currency]()
    
    init(
        currencies: [Currency],
        selectedCurrencyCode: String?,
        onSelectedChange: @escaping (Currency) -> Void
    ) {
        self.currencies = currencies
        self.selectedCurrencyCode = selectedCurrencyCode
        self.onSelectedChange = onSelectedChange
        let nib = R.nib.popupSearchableTableView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.currency_code()
        tableView.register(R.nib.currencyCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func updateSearchResults(keyword: String) {
        searchResults = currencies.filter { (currency) -> Bool in
            currency.code.lowercased().contains(keyword)
        }
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
        let isSelected = currency.code == selectedCurrencyCode
        cell.checkmarkImageView.isHidden = !isSelected
        return cell
    }
    
}

extension CurrencySelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let currency = isSearching ? searchResults[indexPath.row] : currencies[indexPath.row]
        onSelectedChange(currency)
    }
    
}
