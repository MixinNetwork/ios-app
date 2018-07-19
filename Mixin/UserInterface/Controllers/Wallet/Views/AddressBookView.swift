import UIKit

protocol AddressBookViewDelegate: class {
    func addressBookViewWillDismiss(_ view: AddressBookView)
    func addressBookView(didSelectAddress address: Address)
}

class AddressBookView: BottomSheetView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addAddressButton: UIButton!

    weak var delegate: AddressBookViewDelegate?
    
    var asset: AssetItem! {
        didSet {
            titleLabel.text = Localized.ADDRESS_BOOK_TITLE(symbol: asset.symbol)
            reloadAddresses(firstLoad: true)
        }
    }
    
    private let cellReuseId = "AddressCell"
    private var addresses = [Address]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.rowHeight = 80
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "AddressCell", bundle: .main), forCellReuseIdentifier: cellReuseId)
        NotificationCenter.default.addObserver(forName: .AddressDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.reloadAddresses()
        }
    }

    override func presentPopupControllerAnimated() {
        UIApplication.currentActivity()?.view.endEditing(true)
        guard !isShowing else {
            return
        }

        isShowing = true

        self.backgroundColor = windowBackgroundColor
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissPopupControllerAnimated))
        gestureRecognizer.delegate = self
        self.addGestureRecognizer(gestureRecognizer)

        self.popupView.center = getAnimationStartPoint()
        self.alpha = 0

        UIView.animate(withDuration: 0.3, animations: {
            self.popAnimationBody()
        })
    }
    
    override func dismissPopupControllerAnimated() {
        delegate?.addressBookViewWillDismiss(self)
        self.alpha = 1.0
        isShowing = false
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.popupView.center = self.getAnimationStartPoint()
        })
    }

    private func reloadAddresses(firstLoad: Bool = false) {
        let assetId = self.asset.assetId
        DispatchQueue.global().async { [weak self] in
            let addresses = AddressDAO.shared.getAddresses(assetId: assetId)
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.addresses = addresses
                weakSelf.tableView.reloadData()
                weakSelf.tableView.isHidden = addresses.isEmpty
                weakSelf.addAddressButton.isHidden = !addresses.isEmpty
                if firstLoad {
                    weakSelf.refreshRemoteAddresses()
                }
            }
        }
    }

    private func refreshRemoteAddresses() {
        WithdrawalAPI.shared.addresses(assetId: self.asset.assetId, completion: { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let addresses):
                weakSelf.addresses = addresses
                weakSelf.tableView.reloadData()
                AddressDAO.shared.insertOrUpdateAddress(addresses: addresses)
            case .failure:
                break
            }
        })
    }

    @IBAction func managerAddressAction(_ sender: Any) {
        let vc = AddressViewController.instance(asset: asset)
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }

    @IBAction func addAddressAction(_ sender: Any) {
        let vc = NewAddressViewController.instance(asset: asset)
        UIApplication.rootNavigationController()?.pushViewController(vc, animated: true)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    class func instance() -> AddressBookView {
        return Bundle.main.loadNibNamed("AddressBookView", owner: nil, options: nil)?.first as! AddressBookView
    }
    
}

extension AddressBookView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! AddressCell
        cell.render(address: addresses[indexPath.row], asset: asset)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.addressBookView(didSelectAddress: addresses[indexPath.row])
    }

}
