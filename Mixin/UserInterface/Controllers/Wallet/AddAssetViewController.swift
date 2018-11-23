import UIKit

class AddAssetViewController: UIViewController {
    
    @IBOutlet weak var saveButton: BusyButton!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let cellReuseId = "add_asset"
    private let searchQueue = OperationQueue()
    private let textFieldClearButton = UIButton()
    
    private var topAssets = [AssetItem]()
    private var searchResult = [(asset: AssetItem, forceSelected: Bool)]()
    private var lastKeyword = ""
    
    private var isSearching: Bool {
        return !keyword.isEmpty
    }
    
    private var keyword: String {
        return (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func instance() -> UIViewController {
        return Storyboard.wallet.instantiateViewController(withIdentifier: "add_asset")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textFieldClearButton.frame.size = CGSize(width: 42, height: 70)
        textFieldClearButton.imageView?.contentMode = .center
        textFieldClearButton.setImage(UIImage(named: "Wallet/ic_clear"), for: .normal)
        textFieldClearButton.addTarget(self, action: #selector(clearTextField(_:)), for: .touchUpInside)
        textField.delegate = self
        textField.rightViewMode = .whileEditing
        textField.rightView = textFieldClearButton
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(reloadWithLocalTopAssets), name: TopAssetsDAO.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        reloadWithLocalTopAssets()
        ConcurrentJobQueue.shared.addJob(job: RefreshTopAssetsJob())
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = self.keyword
        textFieldClearButton.isHidden = keyword.isEmpty
        guard textField.markedTextRange == nil else {
            return
        }
        guard !keyword.isEmpty else {
            activityIndicator.stopAnimating()
            tableView.reloadData()
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        lastKeyword = keyword
        activityIndicator.startAnimating()
        searchQueue.cancelAllOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            guard !op.isCancelled else {
                return
            }
            let result: [Asset]
            switch AssetAPI.shared.search(keyword: keyword) {
            case .success(let assets):
                result = assets
            case .failure:
                result = []
            }
            let assetItems = result.map({ (asset) -> (AssetItem, Bool) in
                let chainIconUrl = AssetDAO.shared.getChainIconUrl(chainId: asset.chainId)
                let item = AssetItem.createAsset(asset: asset, chainIconUrl: chainIconUrl)
                let alreadyHasTheAsset = AssetDAO.shared.isExist(assetId: asset.assetId)
                return (item, alreadyHasTheAsset)
            })
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                if self.isSearching {
                    self.activityIndicator.stopAnimating()
                    self.searchResult = assetItems
                    self.tableView.reloadData()
                }
            }
        }
        searchQueue.addOperation(op)
    }
    
    @IBAction func saveAction(_ sender: Any) {
        guard let indices = tableView.indexPathsForSelectedRows?.map({ $0.row }) else {
            return
        }
        saveButton.isBusy = true
        var items = [AssetItem]()
        if isSearching {
            for index in indices {
                items.append(searchResult[index].asset)
            }
        } else {
            for index in indices {
                items.append(topAssets[index])
            }
        }
        DispatchQueue.global().async { [weak self] in
            let assets = items.map(Asset.createAsset)
            AssetDAO.shared.insertOrUpdateAssets(assets: assets)
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    @IBAction func popAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func clearTextField(_ sender: Any) {
        textField.text = nil
        textFieldClearButton.isHidden = true
        activityIndicator.stopAnimating()
        tableView.reloadData()
    }
    
    @objc func reloadWithLocalTopAssets() {
        DispatchQueue.global().async { [weak self] in
            let topAssets = TopAssetsDAO.shared.getAssets()
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.topAssets = topAssets
                if !weakSelf.isSearching {
                    weakSelf.activityIndicator.stopAnimating()
                    weakSelf.tableView.reloadData()
                }
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = AppDelegate.current.window!.bounds.height
        keyboardPlaceholderHeightConstraint.constant = windowHeight - endFrame.origin.y
    }
    
}

extension AddAssetViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.backgroundColor = .white
        return true
    }
    
}

extension AddAssetViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResult.count : topAssets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath) as! SearchAssetCell
        if isSearching {
            let result = searchResult[indexPath.row]
            cell.render(asset: result.asset, forceSelected: result.forceSelected)
        } else {
            let asset = topAssets[indexPath.row]
            cell.render(asset: asset, forceSelected: false)
        }
        return cell
    }
    
}

extension AddAssetViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if isSearching {
            let isForceSelected = searchResult[indexPath.row].forceSelected
            return isForceSelected ? nil : indexPath
        } else {
            return indexPath
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        saveButton.isEnabled = tableView.indexPathForSelectedRow != nil
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        saveButton.isEnabled = tableView.indexPathForSelectedRow != nil
    }
    
}

extension AddAssetViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
            if keyword.isEmpty {
                textField.backgroundColor = .clear
            }
        }
    }
    
}
