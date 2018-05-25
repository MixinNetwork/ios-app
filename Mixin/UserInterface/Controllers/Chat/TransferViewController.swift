import UIKit

class TransferViewController: UIViewController, MixinNavigationAnimating {

    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var memoTextField: UITextField!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var transferToLabel: UILabel!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var assetImageView: CornerImageView!
    @IBOutlet weak var assetSymbolLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var assetChooseImageView: UIImageView!
    @IBOutlet weak var loadingAssetsView: UIActivityIndicatorView!
    @IBOutlet weak var chooseAssetsButton: UIButton!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    @IBOutlet weak var continueBottomConstraint: NSLayoutConstraint!

    private let placeHolderFont = UIFont.systemFont(ofSize: 18)
    private let amountFont = UIFont.systemFont(ofSize: 32)
    private let tranceId = UUID().uuidString.lowercased()
    private var isDidAppear = false
    private var user: UserItem!
    private var conversationId = ""
    private var asset: AssetItem?
    private var availableAssets = [AssetItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        amountTextField.delegate = self
        avatarImageView.setImage(with: user)
        transferToLabel.text = Localized.TRANSFER_TITLE_TO(fullName: user.fullName)
        updateUI()
        fetchAssets()
        NotificationCenter.default.addObserver(forName: .AssetsDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.fetchAssets()
        }
    }

    private func fetchAssets() {
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isDidAppear = true
        amountTextField.becomeFirstResponder()
    }

    @IBAction func profileAction(_ sender: Any) {
        guard let user = user else {
            return
        }
        UserWindow.instance().updateUser(user: user).presentView()
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

        PayWindow.shared.presentPopupControllerAnimated(asset: asset, user: user, amount: amount, memo: memo, trackId: tranceId, textfield: amountTextField)
    }

    
    @IBAction func amountEditingChangedAction(_ sender: Any) {
        guard let transferAmount = amountTextField.text else {
            return
        }
        amountTextField.font = transferAmount.isEmpty ? placeHolderFont : amountFont
        continueButton.isHidden = !transferAmount.isNumeric
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

extension TransferViewController {

    override func willMove(toParentViewController parent: UIViewController?) {
        super.willMove(toParentViewController: parent)
        isDidAppear = false
    }

    @objc func keyboardWillChangeFrame(_ sender: Notification) {
        guard let info = sender.userInfo else {
            return
        }
        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let beginKeyboardRect = (info[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        guard let endKeyboardRect = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        guard isDidAppear else {
            return
        }

        UIView.animate(withDuration: duration, animations: {
            self.showOrHideKeyboard(beginKeyboardRect, endKeyboardRect)
        })
    }

    func showOrHideKeyboard(_ beginKeyboardRect: CGRect, _ endKeyboardRect: CGRect) {
        let bounds = UIScreen.main.bounds
        if endKeyboardRect.origin.y == bounds.height || endKeyboardRect.origin.y == bounds.width {
            continueBottomConstraint.constant = 0
        } else {
            if #available(iOS 11.0, *) {
                continueBottomConstraint.constant = -endKeyboardRect.height + view.safeAreaInsets.bottom
            } else {
                continueBottomConstraint.constant = -endKeyboardRect.height
            }
        }
        self.view.layoutIfNeeded()
    }

}
