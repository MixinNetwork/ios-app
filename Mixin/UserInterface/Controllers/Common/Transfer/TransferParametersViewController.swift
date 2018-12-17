import UIKit

class TransferParametersViewController: UIViewController, TransferContextAccessible {
    
    @IBOutlet weak var iconView: ChainSubscriptedAssetIconView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var assetSymbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var changeAssetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    
    @IBOutlet weak var continueButtonBottomConstraint: NSLayoutConstraint!
    
    private let placeHolderFont = UIFont.systemFont(ofSize: 14)
    private let amountFont = UIFont.systemFont(ofSize: 32)
    
    private var availableAssets = [AssetItem]()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        amountTextField.delegate = self
        memoTextField.delegate = self
        amountTextField.becomeFirstResponder()
        reloadAvailableAsset()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        amountTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        amountTextField.resignFirstResponder()
        memoTextField.resignFirstResponder()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let destination = segue.destination as? TransferAssetSelectorViewController {
            destination.assets = availableAssets
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let beginFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
        }
        let windowHeight = AppDelegate.current.window!.frame.height
        continueButtonBottomConstraint.constant = windowHeight - endFrame.origin.y
        if abs(beginFrame.origin.y - windowHeight) < 1 {
            view.layoutIfNeeded()
        }
    }
    
    @IBAction func amountEditingChangedAction(_ sender: Any) {
        let amountIsEmpty = amountTextField.text.isEmpty
        amountTextField.font = amountIsEmpty ? placeHolderFont : amountFont
        continueButton.isHidden = amountIsEmpty
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard let context = context, let amount = amountTextField.text else {
            return
        }
        context.amount = amount
        transferViewController?.confirmPayment()
    }
    
}

extension TransferParametersViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountTextField else {
            return true
        }
        let newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if newText.isEmpty {
            return true
        } else if newText.isNumeric {
            let components = newText.components(separatedBy: currentDecimalSeparator)
            return components.count == 1 || components[1].count <= 8
        } else {
            return false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == amountTextField {
            memoTextField.becomeFirstResponder()
        } else if textField == memoTextField {
            continueAction(textField)
        }
        return false
    }
    
}

extension TransferParametersViewController {
    
    private func reloadData() {
        iconView.prepareForReuse()
        if let asset = self.context?.asset {
            iconView.setIcon(asset: asset)
            assetSymbolLabel.text = asset.symbol
            balanceLabel.text = asset.localizedBalance
        } else {
            iconView.iconImageView.image = #imageLiteral(resourceName: "ic_wallet_xin")
            iconView.chainImageView.image = #imageLiteral(resourceName: "ic_wallet_xin")
            assetSymbolLabel.text = "XIN"
            balanceLabel.text = "0"
        }
        amountTextField.text = nil
        memoTextField.text = nil
        amountEditingChangedAction(self)
    }
    
    @objc private func reloadAvailableAsset() {
        DispatchQueue.global().async { [weak self] in
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.availableAssets = assets
                weakSelf.changeAssetButton.isUserInteractionEnabled = !assets.isEmpty
                weakSelf.loadingIndicator.stopAnimating()
            }
        }
    }
    
}
