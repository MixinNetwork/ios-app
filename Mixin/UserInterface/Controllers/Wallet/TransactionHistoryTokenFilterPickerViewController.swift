import UIKit
import MixinServices

class TransactionHistoryTokenFilterPickerViewController<Token: MixinServices.Token>: TransactionHistoryFilterPickerViewController, UITableViewDelegate {
    
    let selectedTokenReuseIdentifier = "st"
    
    var tokens: [Token] = []
    var selectedAssetIDs: Set<String>
    var selectedTokens: [Token]
    
    var searchResults: [Token] = []
    
    var tokenModels: [Token] {
        isSearching ? searchResults : tokens
    }
    
    init(selectedTokens: [Token]) {
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
        tableView.delegate = self
        
        collectionView.register(SelectedTokenCell.self, forCellWithReuseIdentifier: selectedTokenReuseIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        
        if !selectedAssetIDs.isEmpty {
            showSelections(animated: false)
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
