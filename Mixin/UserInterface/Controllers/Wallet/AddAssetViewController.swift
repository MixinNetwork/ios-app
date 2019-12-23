import UIKit

class AddAssetViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var noResultIndicator: UIView!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let cellReuseId = "add_asset"
    private let searchQueue = OperationQueue()
    
    private var topAssets = [AssetItem]()
    private var searchResults = [(asset: AssetItem, forceSelected: Bool)]()
    private var lastKeyword = ""
    private var selections = Set<String>() // Key is asset id
    
    private var textField: UITextField {
        return searchBoxView.textField
    }
    
    private var keyword: String {
        return (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isSearching: Bool {
        return !keyword.isEmpty
    }
    
    static func instance() -> UIViewController {
        let vc = R.storyboard.wallet.add_asset()!
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_TITLE_ADD_ASSET)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        textField.addTarget(self, action: #selector(search(_:)), for: .editingChanged)
        textField.returnKeyType = .search
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(reloadWithLocalTopAssets), name: TopAssetsDAO.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        reloadWithLocalTopAssets()
        ConcurrentJobQueue.shared.addJob(job: RefreshTopAssetsJob())
    }
    
    @IBAction func popAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func search(_ sender: Any) {
        let keyword = self.keyword
        guard textField.markedTextRange == nil else {
            if tableView.isDragging {
                reloadTableViewAndSelections()
            }
            return
        }
        guard !keyword.isEmpty else {
            activityIndicator.stopAnimating()
            reloadTableViewAndSelections()
            lastKeyword = ""
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
                let chainAsset = AssetDAO.shared.getAsset(assetId: asset.chainId)
                let item = AssetItem(asset: asset, chainIconUrl: chainAsset?.iconUrl, chainName: chainAsset?.name)
                let alreadyHasTheAsset = AssetDAO.shared.isExist(assetId: asset.assetId)
                return (item, alreadyHasTheAsset)
            })
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                if self.isSearching {
                    self.activityIndicator.stopAnimating()
                    self.searchResults = assetItems
                    self.reloadTableViewAndSelections()
                }
            }
        }
        searchQueue.addOperation(op)
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
                    weakSelf.reloadTableViewAndSelections()
                }
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = AppDelegate.current.window.bounds.height
        keyboardPlaceholderHeightConstraint.constant = windowHeight - endFrame.origin.y
        UIView.performWithoutAnimation {
            self.view.layoutIfNeeded()
        }
    }
    
    private func asset(for indexPath: IndexPath) -> AssetItem {
        if isSearching {
            return searchResults[indexPath.row].asset
        } else {
            return topAssets[indexPath.row]
        }
    }
    
    private func reloadTableViewAndSelections() {
        tableView.reloadData()
        if isSearching {
            noResultIndicator.isHidden = !searchResults.isEmpty
            for (row, result) in searchResults.enumerated() where selections.contains(result.asset.assetId) {
                let indexPath = IndexPath(row: row, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        } else {
            noResultIndicator.isHidden = true
            for (row, asset) in topAssets.enumerated() where selections.contains(asset.assetId) {
                let indexPath = IndexPath(row: row, section: 0)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
        }
    }
    
}

extension AddAssetViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        guard let indices = tableView.indexPathsForSelectedRows?.map({ $0.row }) else {
            return
        }
        container?.rightButton.isBusy = true
        var items = [AssetItem]()
        if isSearching {
            for index in indices {
                items.append(searchResults[index].asset)
            }
        } else {
            for index in indices {
                items.append(topAssets[index])
            }
        }
        DispatchQueue.global().async { [weak navigationController] in
            let assets = items.map(Asset.init)
            AssetDAO.shared.insertOrUpdateAssets(assets: assets)
            DispatchQueue.main.async {
                navigationController?.popViewController(animated: true)
                showAutoHiddenHud(style: .notification, text: Localized.TOAST_SAVED)
            }
        }
    }
    
    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        rightButton.setTitleColor(.theme, for: .normal)
        rightButton.setTitleColor(.accessoryText, for: .disabled)
    }
    
    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }
    
}

extension AddAssetViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension AddAssetViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResults.count : topAssets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath) as! SearchAssetCell
        if isSearching {
            let result = searchResults[indexPath.row]
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
            let (asset, forceSelected) = searchResults[indexPath.row]
            if AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] != nil {
                let alert = UIAlertController(title: R.string.localizable.wallet_asset_is_hidden_prompt(), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: R.string.localizable.action_unhide(), style: .default, handler: { (_) in
                    AppGroupUserDefaults.Wallet.hiddenAssetIds[asset.assetId] = nil
                    showAutoHiddenHud(style: .notification, text: R.string.localizable.wallet_asset_is_unhidden())
                }))
                present(alert, animated: true, completion: nil)
                return nil
            } else {
                return forceSelected ? nil : indexPath
            }
        } else {
            return indexPath
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let assetId = self.asset(for: indexPath).assetId
        selections.insert(assetId)
        container?.rightButton.isEnabled = !selections.isEmpty
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let assetId = self.asset(for: indexPath).assetId
        selections.remove(assetId)
        container?.rightButton.isEnabled = !selections.isEmpty
    }
    
}

extension AddAssetViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
}
