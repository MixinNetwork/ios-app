import UIKit
import MixinServices

final class MarketAlertCoinPickerViewController: TransactionHistoryFilterPickerViewController {
    
    protocol Delegate: AnyObject {
        
        func marketAlertCoinPickerViewController(
            _ controller: MarketAlertCoinPickerViewController,
            didPickCoins coins: [MarketAlertCoin]
        )
        
    }
    
    weak var delegate: Delegate?
    
    private let selectedTokenReuseIdentifier = "st"
    
    private var coins: [MarketAlertCoin] = []
    private var selectedCoinIDs: Set<String>
    private var selectedCoins: [MarketAlertCoin]
    
    private var searchResults: [MarketAlertCoin] = []
    
    private var tokenModels: [MarketAlertCoin] {
        isSearching ? searchResults : coins
    }
    
    init(selectedCoins: [MarketAlertCoin]) {
        self.selectedCoinIDs = Set(selectedCoins.map(\.coinID))
        self.selectedCoins = selectedCoins
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        
        hideSegmentControlWrapperView()
        
        tableView.register(R.nib.checkmarkTokenCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        collectionView.register(SelectedTokenCell.self, forCellWithReuseIdentifier: selectedTokenReuseIdentifier)
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        
        if !selectedCoinIDs.isEmpty {
            showSelections(animated: false)
        }
        
        queue.addOperation {
            let coins = MarketDAO.shared.allMarketAlertCoins()
            DispatchQueue.main.sync {
                self.coins = coins
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
    }
    
    override func search(keyword: String) {
        queue.cancelAllOperations()
        let op = BlockOperation()
        let coins = self.coins
        op.addExecutionBlock { [unowned op, weak self] in
            let searchResults = coins.filter { token in
                token.symbol.lowercased().contains(keyword)
                    || token.name.lowercased().contains(keyword)
            }
            DispatchQueue.main.sync {
                guard let self, !op.isCancelled else {
                    return
                }
                self.searchingKeyword = keyword
                self.searchResults = searchResults
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.marketAlertCoinPickerViewController(self, didPickCoins: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.marketAlertCoinPickerViewController(self, didPickCoins: selectedCoins)
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        var indexPaths: [IndexPath] = []
        for (row, token) in tokenModels.enumerated() where selectedCoinIDs.contains(token.coinID) {
            let indexPath = IndexPath(row: row, section: 0)
            indexPaths.append(indexPath)
        }
        for indexPath in indexPaths {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
}

extension MarketAlertCoinPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokenModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
        let token = tokenModels[indexPath.row]
        cell.load(coin: token)
        return cell
    }
    
}

extension MarketAlertCoinPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let token = tokenModels[indexPath.row]
        let (inserted, _) = selectedCoinIDs.insert(token.coinID)
        if inserted {
            let indexPath = IndexPath(item: selectedCoins.count, section: 0)
            selectedCoins.append(token)
            collectionView.insertItems(at: [indexPath])
        }
        showSelections(animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let token = tokenModels[indexPath.row]
        selectedCoinIDs.remove(token.coinID)
        if let index = selectedCoins.firstIndex(where: { $0.coinID == token.coinID }) {
            selectedCoins.remove(at: index)
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.deleteItems(at: [indexPath])
        }
        if selectedCoinIDs.isEmpty {
            hideSelections()
        }
    }
    
}

extension MarketAlertCoinPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        selectedCoins.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: selectedTokenReuseIdentifier, for: indexPath) as! SelectedTokenCell
        let token = selectedCoins[indexPath.row]
        cell.load(coin: token)
        cell.delegate = self
        return cell
    }
    
}

extension MarketAlertCoinPickerViewController: SelectedItemCellDelegate {
    
    func selectedItemCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let deselected = selectedCoins.remove(at: indexPath.row)
        selectedCoinIDs.remove(deselected.coinID)
        collectionView.deleteItems(at: [indexPath])
        if let row = tokenModels.firstIndex(where: { $0.coinID == deselected.coinID }) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.deselectRow(at: indexPath, animated: true)
        }
        if selectedCoinIDs.isEmpty {
            hideSelections()
        }
    }
    
}
