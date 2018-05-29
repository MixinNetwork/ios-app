import UIKit

class NewAddressViewController: UIViewController {

    @IBOutlet weak var labelTextField: UITextField!
    @IBOutlet weak var addressTextView: PlaceholderTextView!

    @IBOutlet weak var addressTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private var asset: AssetItem!
    private var addressValue: String {
        return addressTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var label: String {
        return labelTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var successCallback: ((Address) -> Void)?
    private var address: Address?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addressTextView.delegate = self
        addressTextView.textContainerInset = .zero
        addressTextView.textContainer.lineFragmentPadding = 0
        container?.rightButton.isEnabled = false
        container?.rightButton.setTitleColor(.systemTint, for: .normal)
        if let address = address {
            labelTextField.text = address.label
            addressTextView.text = address.publicKey
            checkLabelAndAddressAction(self)
            textViewDidChange(addressTextView)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        labelTextField.becomeFirstResponder()
    }

    @IBAction func checkLabelAndAddressAction(_ sender: Any) {
        container?.rightButton.isEnabled = !addressValue.isEmpty && !label.isEmpty
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
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        keyboardPlaceholderHeightConstraint.constant = endFrame.height
        view.layoutIfNeeded()
    }

    class func instance(asset: AssetItem, address: Address? = nil, successCallback: ((Address) -> Void)? = nil) -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "new_address") as! NewAddressViewController
        vc.asset = asset
        vc.successCallback = successCallback
        vc.address = address
        return ContainerViewController.instance(viewController: vc, title: address == nil ? Localized.ADDRESS_NEW_TITLE(symbol: asset.symbol) : Localized.ADDRESS_EDIT_TITLE(symbol: asset.symbol))
    }

}

extension NewAddressViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        guard let actionButton = container?.rightButton, !actionButton.isBusy else {
            return
        }
        guard !addressValue.isEmpty && !label.isEmpty else {
            return
        }
        addressTextView.isUserInteractionEnabled = false
        labelTextField.isEnabled = false
        actionButton.isBusy = true
        PinTipsView.instance(tips: Localized.WALLET_PASSWORD_ADDRESS_TIPS) { [weak self](pin) in
            self?.saveAddressAction(pin: pin)
        }.presentPopupControllerAnimated()
    }

    private func saveAddressAction(pin: String) {
        let assetId = asset.assetId
        let request = AddressRequest(assetId: assetId, publicKey: addressValue, label: label, pin: pin)
        WithdrawalAPI.shared.save(address: request) { [weak self](result) in
            switch result {
            case let .success(address):
                AddressDAO.shared.insertOrUpdateAddress(addresses: [address])
                if let weakSelf = self {
                    if weakSelf.address == nil {
                        WalletUserDefault.shared.lastWithdrawalAddress[assetId] = address.addressId
                    }
                    weakSelf.successCallback?(address)
                    weakSelf.navigationController?.popViewController(animated: true)
                }
            case .failure:
                self?.container?.rightButton.isBusy = false
                self?.addressTextView.isUserInteractionEnabled = true
                self?.labelTextField.isEnabled = true
                self?.addressTextView.becomeFirstResponder()
            }
        }
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_SAVE
    }

}

extension NewAddressViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        container?.rightButton.isEnabled = !addressValue.isEmpty && !label.isEmpty
        let sizeToFit = CGSize(width: addressTextView.bounds.width, height: UILayoutFittingExpandedSize.height)
        let height = addressTextView.sizeThatFits(sizeToFit).height
        addressTextViewHeightConstraint.constant = height
        view.layoutIfNeeded()
        addressTextView.isScrollEnabled = addressTextView.bounds.height < height
    }

}
