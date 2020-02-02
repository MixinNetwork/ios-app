import UIKit
import MixinServices

class CurrencySelectorViewController: PopupSearchableTableViewController {
    
    private let currencies: [Currency] = {
        var currencies = Currency.all
        if let index = currencies.firstIndex(where: { $0.code == Currency.current.code }) {
            let selected = currencies.remove(at: index)
            currencies.insert(selected, at: 0)
        }
        return currencies
    }()
    
    private var searchResults = [Currency]()
    private lazy var hud = Hud()
    
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
        cell.checkmarkView.status = isSelected ? .selected : .hidden
        
        return cell
    }
    
}

extension CurrencySelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let currency = isSearching ? searchResults[indexPath.row] : currencies[indexPath.row]
        hud.show(style: .busy, text: "", on: self.view)

        AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest(fiat_currency: currency.code), completion: { [weak self] (result) in
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                Currency.refreshCurrentCurrency()
                self?.hud.set(style: .notification, text: R.string.localizable.toast_saved())
                self?.dismiss(animated: true, completion: nil)
            case let .failure(error):
                self?.hud.set(style: .error, text: error.localizedDescription)
            }
            self?.hud.scheduleAutoHidden()
        })
    }
    
}
