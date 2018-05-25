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
                return
            }
            addressTextField.text = "\(addr.label) (\(addr.publicKey.toSimpleKey()))"
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
        reloadTransactionFeeHint()
        assetBalanceLabel.text = asset.balance
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
    
    private func reloadTransactionFeeHint() {
        AssetAPI.shared.fee(assetId: asset.assetId) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success(let fee):
                weakSelf.transactionFeeHintLabel.attributedText = weakSelf.transactionFeeHint(fee: fee)
                weakSelf.transactionFeeHintLabel.isHidden = false
                weakSelf.requestingFeeIndicator.stopAnimating()
            case .failure(_, _):
                DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: {
                    weakSelf.reloadTransactionFeeHint()
                })
            }
        }
    }
    
    private func transactionFeeHint(fee: Fee) -> NSAttributedString {
        let symbol = AssetDAO.shared.getAsset(assetId: fee.assetId)?.symbol ?? ""
        let feeRepresentation = fee.amount + " " + symbol
        let hint = Localized.WALLET_HINT_TRANSACTION_FEE(feeRepresentation: feeRepresentation, symbol: asset.symbol)
        let attributedHint = NSMutableAttributedString(string: hint, attributes: transactionLabelAttribute)
        let feeRepresentationRange = (hint as NSString).range(of: feeRepresentation)
        attributedHint.addAttributes(transactionLabelBoldAttribute, range: feeRepresentationRange)
        return attributedHint
    }
    
}
