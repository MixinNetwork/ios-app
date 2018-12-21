import UIKit
import LocalAuthentication
import SwiftMessages
import AudioToolbox

protocol PaymentConfirmationDelegate: class {
    func paymentConfirmationViewController(_ viewController: PaymentConfirmationViewController, paymentDidFinishedWithError error: Error?)
}

class PaymentConfirmationViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIStackView!
    @IBOutlet weak var dismissButton: GrabberButton!
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var iconView: ChainSubscriptedAssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var usdValueLabel: UILabel!
    @IBOutlet weak var memoView: UIView!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var authWrapperView: UIView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var paySuccessImageView: UIImageView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: PaymentConfirmationDelegate?
    
    var context: PaymentContext! {
        didSet {
            reloadData()
        }
    }
    
    var biometricAuthIsAvailable: Bool {
        guard #available(iOS 11.0, *) else {
            return false
        }
        guard WalletUserDefault.shared.isBiometricPay else {
            return false
        }
        guard !biometricPayTimedOut else {
            return false
        }
        guard biometryType != .none else {
            return false
        }
        return true
    }
    
    private var didPerformBiometricAuth = false
    private var biometricPayTimedOut: Bool {
        return Date().timeIntervalSince1970 - WalletUserDefault.shared.lastInputPinTime >= WalletUserDefault.shared.pinInterval
    }
    
    static func instance() -> PaymentConfirmationViewController {
        return Storyboard.common.instantiateViewController(withIdentifier: "transfer_confirmation") as! PaymentConfirmationViewController
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if ScreenSize.current == .inch3_5 {
            pinField.cellLength = 8
            iconView.chainIconWidth = 8
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        pinField.resignFirstResponder()
        super.viewWillDisappear(animated)
    }
    
    @IBAction func pinEditingChanged(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        loadingIndicator.startAnimating()
        pinField.isHidden = true
        pay(pin: pinField.text)
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        if presentingViewController is TransferViewController {
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        keyboardPlaceholderHeightConstraint.constant = AppDelegate.current.window!.frame.height - endFrame.origin.y
        updatePreferredContentSize()
        view.layoutIfNeeded()
    }
    
}

extension PaymentConfirmationViewController {
    
    private func reloadData() {
        let asset = context.asset!
        switch context.category {
        case .transfer(let user):
            destinationLabel.text = Localized.PAY_TRANSFER_TITLE(fullname: user.fullName)
            mixinIDLabel.text = user.identityNumber
            statusLabel.text = Localized.TRANSFER_PAY_PASSWORD
        case .withdrawal(let address):
            if asset.isAccount {
                destinationLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.accountName ?? "")
                mixinIDLabel.text = address.accountTag
            } else {
                destinationLabel.text = Localized.PAY_WITHDRAWAL_TITLE(label: address.label ?? "")
                mixinIDLabel.text = address.publicKey?.toSimpleKey()
            }
            statusLabel.text = Localized.WALLET_WITHDRAWAL_PAY_PASSWORD
        }
        iconView.prepareForReuse()
        iconView.setIcon(asset: asset)
        memoView.isHidden = context.memo.isEmpty
        loadingIndicator.stopAnimating()
        pinField.isHidden = false
        pinField.clear()
        memoLabel.text = context.memo
        amountLabel.text = CurrencyFormatter.localizedString(from: context.amount, locale: .current, format: .pretty, sign: .whenNegative, symbol: .custom(asset.symbol))
        usdValueLabel.text = CurrencyFormatter.localizedString(from: context.amount.doubleValue * asset.priceUsd.doubleValue, format: .legalTender, sign: .never, symbol: .usd)
        paySuccessImageView.isHidden = true
        pinField.becomeFirstResponder()
        
        if biometricAuthIsAvailable {
            payWithBiometricAuth()
        } else {
            DispatchQueue.main.async(execute: alertScreenCapturedIfNeeded)
        }
        view.layoutIfNeeded()
        updatePreferredContentSize()
    }
    
    private func pay(pin: String) {
        pinField.receivesInput = false
        dismissButton.isEnabled = false
        let context = self.context!
        let assetId = context.asset.assetId
        let completion = { (result: APIResult<Snapshot>) in
            switch result {
            case let .success(snapshot):
                switch context.category {
                case .transfer(_):
                    WalletUserDefault.shared.defalutTransferAssetId = assetId
                case .withdrawal(let address):
                    ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(assetId: snapshot.assetId))
                    WalletUserDefault.shared.lastWithdrawalAddress[assetId] = address.addressId
                }
                SnapshotDAO.shared.insertOrReplaceSnapshots(snapshots: [snapshot])
                if !self.didPerformBiometricAuth {
                    WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                }
                self.loadingIndicator.stopAnimating()
                self.paySuccessImageView.isHidden = false
                self.statusLabel.text = Localized.ACTION_DONE
                UIDevice.current.playPaymentSuccess()
                self.delegate?.paymentConfirmationViewController(self, paymentDidFinishedWithError: nil)
            case let .failure(error):
                self.delegate?.paymentConfirmationViewController(self, paymentDidFinishedWithError: error)
            }
        }
        
        let generalizedAmount = context.amount.replacingOccurrences(of: currentDecimalSeparator, with: generalDecimalSeparator)
        switch context.category {
        case .transfer(let user):
            CommonUserDefault.shared.hasPerformedTransfer = true
            AssetAPI.shared.transfer(assetId: context.asset.assetId,
                                     opponentId: user.userId,
                                     amount: generalizedAmount,
                                     memo: context.memo,
                                     pin: pin,
                                     traceId: context.traceId,
                                     completion: completion)
        case .withdrawal(let address):
            let request = WithdrawalRequest(addressId: address.addressId,
                                            amount: generalizedAmount,
                                            traceId: context.traceId,
                                            pin: pin,
                                            memo: context.memo)
            WithdrawalAPI.shared.withdrawal(withdrawal: request, completion: completion)
        }
    }
    
    private func payWithBiometricAuth() {
        let prompt = Localized.WALLET_BIOMETRIC_PAY_PROMPT(biometricType: biometryType.localizedName)
        DispatchQueue.global().async { [weak self] in
            guard let weakSelf = self else {
                return
            }
            guard let pin = Keychain.shared.getPIN(prompt: prompt) else {
                DispatchQueue.main.async(execute: weakSelf.alertScreenCapturedIfNeeded)
                return
            }
            DispatchQueue.main.async {
                self?.didPerformBiometricAuth = true
                self?.pinField.insertText(pin)
            }
        }
    }
    
    private func alertScreenCapturedIfNeeded() {
        guard #available(iOS 11.0, *), UIScreen.main.isCaptured else {
            return
        }
        var prompt = Localized.SCREEN_CAPTURED_PIN_LEAKING_HINT
        if biometryType != .none {
            prompt += Localized.BIOMETRY_SUGGESTION(biometricType: biometryType.localizedName)
        }
        alert(prompt)
    }
    
    private func updatePreferredContentSize() {
        preferredContentSize.height = contentView.frame.height + keyboardPlaceholderHeightConstraint.constant
    }
    
}

