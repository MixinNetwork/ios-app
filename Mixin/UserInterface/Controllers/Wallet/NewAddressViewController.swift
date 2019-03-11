import UIKit

class NewAddressViewController: UIViewController {

    @IBOutlet weak var labelTextField: UITextField!
    @IBOutlet weak var addressTextView: PlaceholderTextView!
    @IBOutlet weak var accountNameButton: UIButton!
    @IBOutlet weak var saveButton: RoundedButton!
    @IBOutlet weak var assetView: AssetIconView!

    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var addressTextViewHeightConstraint: NSLayoutConstraint!
    
    private var asset: AssetItem!
    private var addressValue: String {
        return addressTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var labelValue: String {
        return labelTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var successCallback: ((Address) -> Void)?
    private var address: Address?
    
    private weak var pinTipsView: PinTipsView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addressTextView.delegate = self
        addressTextView.textContainerInset = .zero
        addressTextView.textContainer.lineFragmentPadding = 0
        assetView.setIcon(asset: asset)
        if let address = address {
            if asset.isAccount {
                labelTextField.text = address.accountName
                addressTextView.text = address.accountTag
            } else {
                labelTextField.text = address.label
                addressTextView.text = address.publicKey
            }
            checkLabelAndAddressAction(self)
            view.layoutIfNeeded()
            textViewDidChange(addressTextView)
        }

        if asset.isAccount {
            labelTextField.placeholder = Localized.WALLET_ACCOUNT_NAME
            addressTextView.placeholder = Localized.WALLET_ACCOUNT_MEMO
            accountNameButton.isHidden = false
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        labelTextField.becomeFirstResponder()
    }

    @IBAction func checkLabelAndAddressAction(_ sender: Any) {
        if let address = address {
            if asset.isAccount {
                saveButton.isEnabled = !addressValue.isEmpty && !labelValue.isEmpty && (labelValue != address.accountName || addressValue != address.accountTag)
            } else {
                saveButton.isEnabled = !addressValue.isEmpty && !labelValue.isEmpty && (labelValue != address.label || addressValue != address.publicKey)
            }
        } else {
            saveButton.isEnabled = !addressValue.isEmpty && !labelValue.isEmpty
        }
    }

    @IBAction func scanAddressAction(_ sender: Any) {
        navigationController?.pushViewController(CameraViewController.instance(fromWithdrawal: true) { [weak self](address) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.addressTextView.text = address
            weakSelf.textViewDidChange(weakSelf.addressTextView)
        }, animated: true)
    }

    @IBAction func scanAccountNameAction(_ sender: Any) {
        navigationController?.pushViewController(CameraViewController.instance(fromWithdrawal: true) { [weak self](accountName) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.labelTextField.text = accountName
            weakSelf.textViewDidChange(weakSelf.addressTextView)
        }, animated: true)
    }

    
    @IBAction func saveAction(_ sender: Any) {
        guard let actionButton = saveButton, !actionButton.isBusy else {
            return
        }
        guard !addressValue.isEmpty && !labelValue.isEmpty else {
            return
        }
        addressTextView.isUserInteractionEnabled = false
        labelTextField.isEnabled = false
        actionButton.isBusy = true
        pinTipsView = PinTipsView.instance(tips: Localized.WALLET_PASSWORD_ADDRESS_TIPS) { [weak self] (pin) in
            self?.saveAddressAction(pin: pin)
        }
        pinTipsView?.presentPopupControllerAnimated()
    }

    private func saveAddressAction(pin: String) {
        let assetId = asset.assetId
        let publicKey: String? = asset.isAccount ? nil : addressValue
        let label: String? = asset.isAccount ? nil : self.labelValue
        let accountName: String? = asset.isAccount ? self.labelValue : nil
        let accountTag: String? = asset.isAccount ? addressValue : nil
        let request = AddressRequest(assetId: assetId, publicKey: publicKey, label: label, pin: pin, accountName: accountName, accountTag: accountTag)
        WithdrawalAPI.shared.save(address: request) { [weak self](result) in
            switch result {
            case let .success(address):
                AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                if let weakSelf = self {
                    if weakSelf.address == nil {
                        WalletUserDefault.shared.lastWithdrawalAddress[assetId] = address.addressId
                    }
                    weakSelf.successCallback?(address)
                    weakSelf.navigationController?.showHud(style: .notification, text: Localized.TOAST_SAVED)
                    weakSelf.navigationController?.popViewController(animated: true)
                }
            case .failure:
                self?.pinTipsView?.removeFromSuperview()
                self?.saveButton.isBusy = false
                self?.addressTextView.isUserInteractionEnabled = true
                self?.labelTextField.isEnabled = true
                self?.addressTextView.becomeFirstResponder()
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        let windowHeight = AppDelegate.current.window!.bounds.height
        bottomConstraint.constant = windowHeight - endFrame.origin.y + 20
        UIView.performWithoutAnimation {
            self.view.layoutIfNeeded()
        }
    }

    class func instance(asset: AssetItem, address: Address? = nil, successCallback: ((Address) -> Void)? = nil) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "new_address") as! NewAddressViewController
        vc.asset = asset
        vc.successCallback = successCallback
        vc.address = address
        return ContainerViewController.instance(viewController: vc, title: address == nil ? Localized.ADDRESS_NEW_TITLE(symbol: asset.symbol) : Localized.ADDRESS_EDIT_TITLE(symbol: asset.symbol))
    }

}

extension NewAddressViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        checkLabelAndAddressAction(textView)
        let sizeToFit = CGSize(width: addressTextView.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let height = addressTextView.sizeThatFits(sizeToFit).height
        addressTextViewHeightConstraint.constant = height
        view.layoutIfNeeded()
        addressTextView.isScrollEnabled = addressTextView.bounds.height < height
    }

}
