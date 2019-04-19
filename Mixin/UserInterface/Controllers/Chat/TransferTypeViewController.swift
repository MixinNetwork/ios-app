import UIKit

protocol TransferTypeViewControllerDelegate: class {
    func transferTypeViewController(_ viewController: TransferTypeViewController, didSelectAsset asset: AssetItem)
}

class TransferTypeViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    
    weak var delegate: TransferTypeViewControllerDelegate?
    
    var assets = [AssetItem]()
    var asset: AssetItem?
    
    private let cellReuseId = "transfer_type"
    
    private var searchResults = [AssetItem]()
    private var lastKeyword = ""
    
    private var keywordTextField: UITextField {
        return searchBoxView.textField
    }
    
    private var keyword: String {
        return (keywordTextField.text ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isSearching: Bool {
        return !keyword.isEmpty
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updatePreferredContentSizeHeight()
        if let assetId = asset?.assetId, let index = assets.firstIndex(where: { $0.assetId == assetId }) {
            var reordered = assets
            let selected = reordered.remove(at: index)
            reordered.insert(selected, at: 0)
            self.assets = reordered
        }
        let hiddenAssets = WalletUserDefault.shared.hiddenAssets
        self.assets = self.assets.filter({ (asset) -> Bool in
            return hiddenAssets[asset.assetId] == nil
        })
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        keywordTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func searchAction(_ sender: Any) {
        let keyword = self.keyword
        guard keywordTextField.markedTextRange == nil else {
            if tableView.isDragging {
                tableView.reloadData()
            }
            return
        }
        guard !keyword.isEmpty else {
            tableView.reloadData()
            lastKeyword = ""
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        lastKeyword = keyword
        searchResults = assets.filter({ (asset) -> Bool in
            asset.symbol.lowercased().contains(keyword)
        })
        tableView.reloadData()
    }
    
    private func updatePreferredContentSizeHeight() {
        guard let window = AppDelegate.current.window else {
            return
        }
        preferredContentSize.height = window.bounds.height - window.compatibleSafeAreaInsets.top - 56
    }
    
}

extension TransferTypeViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! TransferTypeCell
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        if asset.assetId == self.asset?.assetId {
            cell.checkmarkView.status = .selected
        } else {
            cell.checkmarkView.status = .hidden
        }
        cell.render(asset: asset)
        return cell
    }
    
}

extension TransferTypeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let asset = isSearching ? searchResults[indexPath.row] : assets[indexPath.row]
        delegate?.transferTypeViewController(self, didSelectAsset: asset)
        dismiss(animated: true, completion: nil)
    }
    
}
