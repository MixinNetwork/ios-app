import UIKit
import MixinServices

protocol TransactionHistoryTokenFilterPickerViewControllerDelegate: AnyObject {
    
    func transactionHistoryTokenFilterPickerViewController(
        _ controller: TransactionHistoryTokenFilterPickerViewController,
        didPickTokens tokens: [MixinTokenItem]
    )
    
}

final class TransactionHistoryTokenFilterPickerViewController: TransactionHistoryFilterPickerViewController {
    
    weak var delegate: TransactionHistoryTokenFilterPickerViewControllerDelegate?
    
    private let selectedTokenReuseIdentifier = "st"
    
    private var tokens: [MixinTokenItem] = []
    private var selectedAssetIDs: Set<String>
    private var selectedTokens: [MixinTokenItem]
    
    private var searchResults: [MixinTokenItem] = []
    
    private var tokenModels: [MixinTokenItem] {
        isSearching ? searchResults : tokens
    }
    
    init(selectedTokens: [MixinTokenItem]) {
        self.selectedAssetIDs = Set(selectedTokens.map(\.assetID))
        self.selectedTokens = selectedTokens
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
        
        if !selectedAssetIDs.isEmpty {
            showSelections(animated: false)
        }
        
        queue.addOperation {
            let tokens = TokenDAO.shared.allTokens()
            DispatchQueue.main.sync {
                self.tokens = tokens
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
    }
    
    override func search(keyword: String) {
        queue.cancelAllOperations()
        let op = BlockOperation()
        let tokens = self.tokens
        op.addExecutionBlock { [unowned op, weak self] in
            let searchResults = tokens.filter { token in
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
        delegate?.transactionHistoryTokenFilterPickerViewController(self, didPickTokens: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.transactionHistoryTokenFilterPickerViewController(self, didPickTokens: selectedTokens)
    }
    
    override func reloadTableViewSelections() {
        super.reloadTableViewSelections()
        var indexPaths: [IndexPath] = []
        for (row, token) in tokenModels.enumerated() where selectedAssetIDs.contains(token.assetID) {
            let indexPath = IndexPath(row: row, section: 0)
            indexPaths.append(indexPath)
        }
        for indexPath in indexPaths {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
}

extension TransactionHistoryTokenFilterPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokenModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
        let token = tokenModels[indexPath.row]
        cell.load(token: token)
        return cell
    }
    
}

extension TransactionHistoryTokenFilterPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let token = tokenModels[indexPath.row]
        let (inserted, _) = selectedAssetIDs.insert(token.assetID)
        if inserted {
            let indexPath = IndexPath(item: selectedTokens.count, section: 0)
            selectedTokens.append(token)
            collectionView.insertItems(at: [indexPath])
        }
        showSelections(animated: true)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let token = tokenModels[indexPath.row]
        selectedAssetIDs.remove(token.assetID)
        if let index = selectedTokens.firstIndex(where: { $0.assetID == token.assetID }) {
            selectedTokens.remove(at: index)
            let indexPath = IndexPath(item: index, section: 0)
            collectionView.deleteItems(at: [indexPath])
        }
        if selectedAssetIDs.isEmpty {
            hideSelections(animated: true)
        }
    }
    
}

extension TransactionHistoryTokenFilterPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        selectedTokens.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: selectedTokenReuseIdentifier, for: indexPath) as! SelectedTokenCell
        let token = selectedTokens[indexPath.row]
        cell.load(token: token)
        cell.delegate = self
        return cell
    }
    
}

extension TransactionHistoryTokenFilterPickerViewController: SelectedItemCellDelegate {
    
    func selectedItemCellDidSelectRemove(_ cell: UICollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        let deselected = selectedTokens.remove(at: indexPath.row)
        selectedAssetIDs.remove(deselected.assetID)
        collectionView.deleteItems(at: [indexPath])
        if let row = tokenModels.firstIndex(where: { $0.assetID == deselected.assetID }) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.deselectRow(at: indexPath, animated: true)
        }
        if selectedAssetIDs.isEmpty {
            hideSelections(animated: true)
        }
    }
    
}
