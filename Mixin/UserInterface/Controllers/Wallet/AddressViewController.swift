import UIKit
import MixinServices

class AddressViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var newAddressButton: UIButton!
    
    private let cellReuseId = "address"
    
    private var token: TokenItem!
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
        
        title = R.string.localizable.address()
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_add(),
            target: self,
            action: #selector(newAddressAction)
        )
        
        // UIButton with image and title failed to calculate intrinsicContentSize if bold text is turned on in iOS Display Settings
        // Set lineBreakMode to byClipping as a workaround. Tested on iOS 15.1
        newAddressButton.titleLabel?.lineBreakMode = .byClipping
        
        searchBoxView.textField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        reloadLocalAddresses()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadLocalAddresses),
                                               name: AddressDAO.addressDidChangeNotification,
                                               object: nil)
        AddressAPI.addresses(assetID: token.assetID) { (result) in
            guard case let .success(addresses) = result else {
                return
            }
            DispatchQueue.global().async {
                AddressDAO.shared.insertOrUpdateAddress(addresses: addresses)
            }
        }
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = (searchBoxView.textField.text ?? "").lowercased()
        if keyword.isEmpty {
            searchResult = []
        } else {
            searchResult = addresses.filter { address in
                address.label.lowercased().contains(keyword)
                || address.destination.lowercased().contains(keyword)
            }
        }
        tableView.reloadData()
    }
    
    @IBAction func newAddressAction() {
        let vc = NewAddressViewController.instance(asset: token)
        UIApplication.homeNavigationController?.pushViewController(vc, animated: true)
    }
    
    class func instance(token: TokenItem) -> UIViewController {
        let vc = R.storyboard.wallet.address_list()!
        vc.token = token
        return vc
    }
    
}

extension AddressViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? searchResult.count : addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! AddressCell
        if isSearching {
            cell.render(address: searchResult[indexPath.row], asset: token)
        } else {
            cell.render(address: addresses[indexPath.row], asset: token)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let navigationController = navigationController else {
            return
        }
        let address = isSearching ? searchResult[indexPath.row] : addresses[indexPath.row]
        let vc = TransferOutViewController(token: token, to: .address(address))
        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.lastIndex(of: self) {
            viewControllers.remove(at: index)
        }
        viewControllers.append(vc)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isSearching
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [deleteAction(forRowAt: indexPath)])
    }
    
}

extension AddressViewController {
    
    @objc private func reloadLocalAddresses() {
        let assetId = token.assetID
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
    
    private func deleteAction(forRowAt indexPath: IndexPath) -> UIContextualAction {
        UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { [weak self] (action, _, completionHandler: (Bool) -> Void) in
            guard let self = self else {
                return
            }
            if self.searchBoxView.textField.isFirstResponder {
                self.searchBoxView.textField.resignFirstResponder()
            }
            let address = self.addresses[indexPath.row]
            let preview = EditAddressPreviewViewController(token: token,
                                                           label: address.label,
                                                           destination: address.destination,
                                                           tag: address.tag,
                                                           action: .delete(id: address.addressId))
            self.present(preview, animated: true)
            completionHandler(true)
        }
    }
    
}
