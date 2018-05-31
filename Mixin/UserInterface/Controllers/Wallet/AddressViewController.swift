import UIKit

class AddressViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private lazy var deleteAction = UITableViewRowAction(style: .destructive, title: Localized.MENU_DELETE, handler: tableViewCommitDeleteAction)

    private var asset: AssetItem!
    private var addresses = [Address]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = 80
        tableView.register(UINib(nibName: "AddressCell", bundle: .main), forCellReuseIdentifier: AddressCell.cellReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()

        loadAddresses()
        NotificationCenter.default.addObserver(forName: .AddressDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.loadAddresses()
        }
    }

    private func loadAddresses() {
        let assetId = asset.assetId
        DispatchQueue.global().async { [weak self] in
            let addresses = AddressDAO.shared.getAddresses(assetId: assetId)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.addresses = addresses
                weakSelf.tableView.reloadData()
            }
        }
    }
    
    class func instance(asset: AssetItem) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "address_list") as! AddressViewController
        vc.asset = asset
        let container = ContainerViewController.instance(viewController: vc, title: Localized.ADDRESS_LIST_TITLE)
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }
}

extension AddressViewController: ContainerViewControllerDelegate {
    func barRightButtonTappedAction() {
        let vc = NewAddressViewController.instance(asset: asset)
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }

    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_add")
    }

}

extension AddressViewController {

    private func tableViewCommitDeleteAction(action: UITableViewRowAction, indexPath: IndexPath) {
        let alc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.MENU_DELETE, style: .destructive, handler: { [weak self](action) in
            self?.deleteAction(indexPath: indexPath)
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        present(alc, animated: true, completion: nil)
        tableView.setEditing(false, animated: true)
    }

    private func deleteAction(indexPath: IndexPath) {
        let addressId = addresses[indexPath.row].addressId
        tableView.beginUpdates()
        addresses.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()

        PinTipsView.instance(tips: Localized.WALLET_PASSWORD_ADDRESS_TIPS) { [weak self](pin) in
            self?.saveAddressAction(pin: pin, addressId: addressId)
            }.presentPopupControllerAnimated()
    }

    private func saveAddressAction(pin: String, addressId: String) {
        let assetId = asset.assetId
        WithdrawalAPI.shared.delete(addressId: addressId, pin: pin) { (result) in
            switch result {
            case .success:
                AddressDAO.shared.deleteAddress(assetId: assetId, addressId: addressId)
            case .failure:
                break
            }
        }
    }
}

extension AddressViewController: UITableViewDataSource, UITableViewDelegate {
  
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell{
        let cell = tableView.dequeueReusableCell(withIdentifier: AddressCell.cellReuseId) as! AddressCell
        cell.render(address: addresses[indexPath.row])
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = NewAddressViewController.instance(asset: asset, address: addresses[indexPath.row])
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [deleteAction]
    }
}
