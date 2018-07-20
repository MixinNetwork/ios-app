import UIKit

class TransferViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var transferToLabel: UILabel!
    @IBOutlet weak var continueButtonWrapperView: UIView!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var assetImageView: CornerImageView!
    @IBOutlet weak var assetSymbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var assetChooseImageView: UIImageView!
    @IBOutlet weak var loadingAssetsView: UIActivityIndicatorView!
    @IBOutlet weak var chooseAssetsButton: UIButton!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    @IBOutlet weak var continueWrapperBottomConstraint: NSLayoutConstraint!

    private let placeHolderFont = UIFont.systemFont(ofSize: 18)
    private let amountFont = UIFont.systemFont(ofSize: 32)
    private let tranceId = UUID().uuidString.lowercased()
    private var isDidAppear = false
    private var user: UserItem!
    private var conversationId = ""
    private var asset: AssetItem?
    private var availableAssets = [AssetItem]()
    private var userWindow: UserWindow?
    private var keyboardHeight: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountTextField.delegate = self
        memoTextField.delegate = self
        avatarImageView.setImage(with: user)
        transferToLabel.text = Localized.TRANSFER_TITLE_TO(fullName: user.fullName)
        updateUI()
        fetchAssets()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(fetchAssets), name: .AssetsDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isDidAppear = true
        amountTextField.becomeFirstResponder()
    }
    
    override func willMove(toParentViewController parent: UIViewController?) {
        super.willMove(toParentViewController: parent)
        isDidAppear = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func profileAction(_ sender: Any) {
        guard let user = user else {
            return
        }
        userWindow?.removeFromSuperview()
        userWindow = UserWindow.instance()
        userWindow!.updateUser(user: user).presentView()
    }

    @IBAction func closeAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func changeTransferTypeAction(_ sender: Any) {
        TransferTypeView.instance().presentPopupControllerAnimated(textfield: amountTextField, assets: availableAssets, asset: asset) { [weak self](asset) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.asset = asset
            weakSelf.updateUI()
        }
    }

    @IBAction func continueAction(_ sender: Any) {
        guard let user = self.user, let asset = self.asset else {
            return
        }
        let amount = amountTextField.text ?? ""
        let memo = memoTextField.text ?? ""

        PayWindow.shared.presentPopupControllerAnimated(isTransfer: true, asset: asset, user: user, amount: amount, memo: memo, trackId: tranceId, textfield: amountTextField)
    }
    
    @IBAction func amountEditingChangedAction(_ sender: Any) {
        guard let transferAmount = amountTextField.text else {
            return
        }
        amountTextField.font = transferAmount.isEmpty ? placeHolderFont : amountFont
        let shouldHideContinueButton = !transferAmount.isNumeric
        if continueButtonWrapperView.isHidden != shouldHideContinueButton {
            continueButtonWrapperView.isHidden = shouldHideContinueButton
            updateBottomInset()
        }
    }
    
    @objc func fetchAssets() {
        DispatchQueue.global().async { [weak self] in
            let assets = AssetDAO.shared.getAvailableAssets()
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.availableAssets = assets
                if assets.count > 1 {
                    weakSelf.assetChooseImageView.isHidden = false
                    weakSelf.chooseAssetsButton.isUserInteractionEnabled = true
                }
                weakSelf.loadingAssetsView.stopAnimating()
                weakSelf.loadingAssetsView.isHidden = true
            }
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let keyboardBeginFrame = userInfo[UIKeyboardFrameBeginUserInfoKey] as? CGRect, let keyboardEndFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        keyboardHeight = UIScreen.main.bounds.height - keyboardEndFrame.minY
        continueWrapperBottomConstraint.constant = keyboardHeight
        let keyboardIsVisibleBeforeFrameChange = UIScreen.main.bounds.height - keyboardBeginFrame.minY > 0
        let keyboardIsDismissing = keyboardHeight <= 0
        if keyboardIsVisibleBeforeFrameChange && !keyboardIsDismissing {
            UIView.performWithoutAnimation {
                self.view.layoutIfNeeded()
                self.updateBottomInset()
            }
        } else {
            view.layoutIfNeeded()
            updateBottomInset()
        }
    }
    
    class func instance(user: UserItem, conversationId: String, asset: AssetItem?) -> UIViewController {
        let vc = Storyboard.chat.instantiateViewController(withIdentifier: "transfer") as! TransferViewController
        vc.user = user
        vc.conversationId = conversationId
        vc.asset = asset
        return vc
    }
    
}

extension TransferViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountTextField else {
            return true
        }
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == amountTextField {
            memoTextField.becomeFirstResponder()
        } else if textField == memoTextField {
            continueAction(textField)
        }
        return false
    }
    
}

extension TransferViewController {
    
    private func updateUI() {
        if let asset = self.asset {
            assetImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
            assetSymbolLabel.text = asset.symbol
            balanceLabel.text = asset.localizedBalance
            if let chainIconUrl = asset.chainIconUrl {
                blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
                blockchainImageView.isHidden = false
            } else {
                blockchainImageView.isHidden = true
            }
        } else {
            assetImageView.image = #imageLiteral(resourceName: "ic_wallet_xin")
            blockchainImageView.image = #imageLiteral(resourceName: "ic_wallet_xin")
            assetSymbolLabel.text = "XIN"
            balanceLabel.text = "0"
        }
        amountTextField.text = ""
        memoTextField.text = ""
        amountEditingChangedAction(self)
    }
    
    private func updateBottomInset() {
        let continueButtonHeight = continueButtonWrapperView.isHidden ? 0 : continueButtonWrapperView.frame.height
        var bottomInset = keyboardHeight + continueButtonHeight + contentView.frame.height - scrollView.frame.height
        bottomInset = max(0, bottomInset)
        scrollView.contentInset.bottom = bottomInset
        scrollView.scrollIndicatorInsets.bottom = bottomInset
        updateContentOffsetIfNeeded()
    }
    
    private func updateContentOffsetIfNeeded() {
        guard scrollView.contentInset.bottom > 0 else {
            return
        }
        let y = max(0, scrollView.contentSize.height + scrollView.contentInset.vertical - scrollView.frame.height)
        scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
    }

}
