import UIKit

class AddressViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var newAddressButton: UIButton!
    
    private let cellReuseId = "address"
    
    private lazy var deleteAction = UITableViewRowAction(style: .destructive, title: Localized.MENU_DELETE, handler: tableViewCommitDeleteAction)
    
    private var asset: AssetItem!
    private var addresses = [Address]()
    private var searchResult = [Address]()
    private var isSearching: Bool {
        return !(searchBoxView.textField.text ?? "").isEmpty
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        reloadLocalAddresses()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadLocalAddresses), name: .AddressDidChange, object: nil)
        WithdrawalAPI.shared.addresses(assetId: asset.assetId) { (result) in
            guard case let .success(addresses) = result else {
                return
            }
            DispatchQueue.global().async {
                AddressDAO.shared.insertOrUpdateAddress(addresses: addresses)
            }
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = (searchBoxView.textField.text ?? "").uppercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = addresses.filter { $0.label.uppercased().contains(keyword) }
        }
        tableView.reloadData()
    }
    
    @IBAction func newAddressAction() {
        let vc = NewAddressViewController.instance(asset: asset)
        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = R.storyboard.wallet.address_list()!
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: Localized.ADDRESS_LIST_TITLE)
        return container
    }
    
}

extension AddressViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        newAddressAction()
    }
    
    func imageBarRightButton() -> UIImage? {
        return R.image.ic_title_add()
    }
    
}

extension AddressViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResult.count : addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! AddressCell
        if isSearching {
            cell.render(address: searchResult[indexPath.row], asset: asset)
        } else {
            cell.render(address: addresses[indexPath.row], asset: asset)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let navigationController = navigationController else {
            return
        }
        let address = isSearching ? searchResult[indexPath.row] : addresses[indexPath.row]
        
        let vc = TransferOutViewController.instance(asset: asset, type: .address(address))
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.lastIndex(where: { ($0 as? ContainerViewController)?.viewController == self }) {
            viewControllers.remove(at: index)
        }
        viewControllers.append(vc)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isSearching
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }
    
}

extension AddressViewController {
    
    @objc private func reloadLocalAddresses() {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            let addresses = AddressDAO.shared.getAddresses(assetId: assetId)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.addresses = addresses
                weakSelf.searchBoxView.isHidden = addresses.isEmpty
                weakSelf.newAddressButton.isHidden = !addresses.isEmpty
                weakSelf.tableView.reloadData()
            }
        }
    }
    
    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        if searchBoxView.textField.isFirstResponder {
            searchBoxView.textField.resignFirstResponder()
        }
        let address = addresses[indexPath.row]
        tableView.setEditing(false, animated: true)
        
        AddressWindow.instance().presentPopupControllerAnimated(action: .delete, asset: asset, addressRequest: nil, address: address, dismissCallback: nil)
    }
    
    private func deleteAddress(at indexPath: IndexPath, pin: String) {
        let addressId = addresses[indexPath.row].addressId
        tableView.beginUpdates()
        addresses.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        let assetId = asset.assetId
        WithdrawalAPI.shared.delete(addressId: addressId, pin: pin) { [weak self](result) in
            switch result {
            case .success:
                AddressDAO.shared.deleteAddress(assetId: assetId, addressId: addressId)
            case let .failure(error):
                if error.code == 429 {
                    self?.alert(R.string.localizable.wallet_password_too_many_requests())
                } else {
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
            }
        }
    }
    
}
