import UIKit

class WithdrawalViewController: UIViewController {

    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var assetBalanceLabel: UILabel!
    @IBOutlet weak var assetSymbolLabel: UILabel!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var transactionFeeHintLabel: UILabel!
    @IBOutlet weak var requestingFeeIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var contentViewTopConstraint: NSLayoutConstraint!
    
    private let placeholderFont = UIFont.systemFont(ofSize: 18)
    private let digitsFont = UIFont.systemFont(ofSize: 32)
    private let tranceId = UUID().uuidString.lowercased()
    
    private var asset: AssetItem!
    private var address: Address? {
        didSet {
            guard let addr = address else {
                displayFeeHint(loading: false)
                return
            }
            addressTextField.text = "\(addr.label) (\(addr.publicKey.toSimpleKey()))"
            reloadTransactionFeeHint(addressId: addr.addressId)
        }
    }
    
    private lazy var addressBookView: AddressBookView = {
        let view = AddressBookView.instance()
        view.alpha = 0
        view.asset = self.asset
        view.delegate = self
        return view
    }()

    private lazy var transactionLabelAttribute: [NSAttributedStringKey: Any] = {
        return [.font: transactionFeeHintLabel.font,
                .foregroundColor: transactionFeeHintLabel.textColor]
    }()
    
    private lazy var transactionLabelBoldAttribute: [NSAttributedStringKey: Any] = {
        let normalFont = transactionFeeHintLabel.font!
        let boldFont: UIFont
        if let descriptor = normalFont.fontDescriptor.withSymbolicTraits(.traitBold) {
            boldFont = UIFont(descriptor: descriptor, size: normalFont.pointSize)
        } else {
            boldFont = UIFont.boldSystemFont(ofSize: normalFont.pointSize)
        }
        return [.font: boldFont,
                .foregroundColor: transactionFeeHintLabel.textColor]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountTextField.delegate = self
        assetBalanceLabel.text = asset.localizedBalance
        assetSymbolLabel.text = asset.symbol
        subtitleLabel.text = asset.name
        if abs(UIScreen.main.bounds.width - 320) < 1 {
            contentViewTopConstraint.constant = 0
        }

        loadDefaultAddress()
        self.view.addSubview(addressBookView)
        addressBookView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })

        NotificationCenter.default.addObserver(forName: .DefaultAddressDidChange, object: nil, queue: .main) { [weak self](_) in
            self?.loadDefaultAddress()
        }
    }

    private func loadDefaultAddress() {
        let assetId = self.asset.assetId
        DispatchQueue.global().async { [weak self] in
            let address = AddressDAO.shared.getLastUseAddress(assetId: assetId)
            DispatchQueue.main.async {
                self?.address = address
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if addressBookView.alpha == 0 {
            amountTextField.becomeFirstResponder()
        }
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func nextAction(_ sender: Any) {
        let memo = memoTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let amount = amountTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard amount.isNumeric && address != nil else {
            return
        }
        PayWindow.shared.presentPopupControllerAnimated(asset: asset, address: address, amount: amount, memo: memo, trackId: tranceId, textfield: amountTextField)
    }
    
    @IBAction func addAddressAction(_ sender: Any) {
        addressBookView.presentPopupControllerAnimated()
    }
    
    @IBAction func amountTextFieldChangedAction(_ sender: Any) {
        let amount = amountTextField.text ?? ""
        amountTextField.font = amount.isEmpty ? placeholderFont : digitsFont
        nextButton.isEnabled = amount.isNumeric && address != nil
    }
    
    @IBAction func amountTextFieldDidEndOnExitAction(_ sender: Any) {
        memoTextField.becomeFirstResponder()
    }
    
    class func instance(asset: AssetItem) -> WithdrawalViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "withdrawal") as! WithdrawalViewController
        vc.asset = asset
        return vc
    }
    
}

extension WithdrawalViewController: AddressBookViewDelegate {
    
    func addressBookViewWillDismiss(_ view: AddressBookView) {
        if !(amountTextField.text ?? "").isEmpty && (memoTextField.text ?? "").isEmpty {
            memoTextField.becomeFirstResponder()
        } else {
            amountTextField.becomeFirstResponder()
        }
    }
    
    func addressBookView(didSelectAddress address: Address) {
        addressBookView.dismissPopupControllerAnimated()
        self.address = address
    }

}

extension WithdrawalViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if newText.isEmpty {
            return true
        } else if newText.isNumeric {
            let decimalSeparator = Locale.current.decimalSeparator ?? "."
            let components = newText.components(separatedBy: decimalSeparator)
            return components.count == 1 || components[1].count <= 8
        } else {
            return false
        }
    }

}

extension WithdrawalViewController {
    
    private func reloadTransactionFeeHint(addressId: String) {
        displayFeeHint(loading: true)
        WithdrawalAPI.shared.address(addressId: addressId) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case let .success(address):
                weakSelf.fillFeeHint(address: address)
            case .failure:
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: {
                    self?.reloadTransactionFeeHint(addressId: addressId)
                })
            }
        }
    }

    private func displayFeeHint(loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.transactionFeeHintLabel.isHidden = loading
            self?.requestingFeeIndicator.isHidden = !loading
            if loading {
                self?.requestingFeeIndicator.startAnimating()
            } else {
                self?.requestingFeeIndicator.stopAnimating()
            }
        }
    }
    
    private func fillFeeHint(address: Address) {
        DispatchQueue.global().async { [weak self] in
            guard let asset = AssetDAO.shared.getAsset(assetId: address.assetId), let chainAsset = AssetDAO.shared.getAsset(assetId: asset.chainId) else {
                self?.transactionFeeHintLabel.text = ""
                self?.displayFeeHint(loading: false)
                return
            }

            let feeRepresentation = address.fee + " " + chainAsset.symbol
            var hint = Localized.WALLET_HINT_TRANSACTION_FEE(feeRepresentation: feeRepresentation, name: asset.name)
            var ranges = [(hint as NSString).range(of: feeRepresentation)]
            if address.reserve.toDouble() > 0 {
                let reserveRepresentation = address.reserve + " " + chainAsset.symbol
                let reserveHint = Localized.WALLET_WITHDRAWAL_RESERVE(reserveRepresentation: reserveRepresentation, name: chainAsset.name)
                let reserveRange = (reserveHint as NSString).range(of: reserveRepresentation)
                ranges.append(NSRange(location: hint.count + reserveRange.location, length: reserveRange.length))
                hint += reserveHint
            }

            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }

                let attributedHint = NSMutableAttributedString(string: hint, attributes: weakSelf.transactionLabelAttribute)
                for range in ranges {
                    attributedHint.addAttributes(weakSelf.transactionLabelBoldAttribute, range: range)
                }
                weakSelf.transactionFeeHintLabel.attributedText = attributedHint
                weakSelf.displayFeeHint(loading: false)
            }
        }
    }
    
}
