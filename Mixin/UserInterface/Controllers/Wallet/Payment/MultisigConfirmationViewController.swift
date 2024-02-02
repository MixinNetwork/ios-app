import UIKit
import MixinServices
import Tip

final class MultisigConfirmationViewController: PaymentConfirmationViewController {
    
    enum State {
        case paid
        case signed
        case unlocked
        case pending
    }
    
    enum Error: Swift.Error, LocalizedError {
        
        case sign(Swift.Error?)
        
        var errorDescription: String? {
            switch self {
            case .sign(let error):
                return error?.localizedDescription ?? "Null signature"
            }
        }
        
    }
    
    private let requestID: String
    private let token: TokenItem
    private let amount: Decimal
    private let sendersThreshold: Int
    private let senders: [UserItem]
    private let receiversThreshold: Int
    private let receivers: [UserItem]
    private let rawTransaction: String
    private let viewKeys: String
    private let action: MultisigAction
    private let index: Int
    private let state: State

    init(
        requestID: String,
        token: TokenItem,
        amount: Decimal,
        sendersThreshold: Int,
        senders: [UserItem],
        receiversThreshold: Int,
        receivers: [UserItem],
        rawTransaction: String,
        viewKeys: String,
        action: MultisigAction,
        index: Int,
        state: State
    ) {
        self.requestID = requestID
        self.token = token
        self.amount = amount
        self.sendersThreshold = sendersThreshold
        self.senders = senders
        self.receiversThreshold = receiversThreshold
        self.receivers = receivers
        self.rawTransaction = rawTransaction
        self.viewKeys = viewKeys
        self.action = action
        self.index = index
        self.state = state
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        insertMultisigPatternView { patternView in
            patternView.showSendersButton.addTarget(self, action: #selector(showSenders(_:)), for: .touchUpInside)
            patternView.showReceiversButton.addTarget(self, action: #selector(showReceivers(_:)), for: .touchUpInside)
            patternView.reloadData(senders: senders, receivers: receivers, action: action)
        }
        
        assetIconView.setIcon(token: token)
        
        let fiatMoneyAmount = amount * token.decimalUSDPrice * Decimal(Currency.current.rate)
        amountLabel.text = CurrencyFormatter.localizedString(from: amount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
        valueLabel.text = CurrencyFormatter.estimatedFiatMoneyValue(amount: fiatMoneyAmount)
        
        switch state {
        case .paid:
            authenticationViewController?.layoutForAuthenticationFailure(description: R.string.localizable.pay_paid(), retryAction: .notAllowed)
        case .signed:
            authenticationViewController?.layoutForAuthenticationFailure(description: R.string.localizable.multisig_state_signed(), retryAction: .notAllowed)
        case .unlocked:
            authenticationViewController?.layoutForAuthenticationFailure(description: R.string.localizable.multisig_state_unlocked(), retryAction: .notAllowed)
        case .pending:
            break
        }
    }
    
    @objc private func finish(_ sender: Any) {
        authenticationViewController?.presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func showSenders(_ sender: Any) {
        let viewController = MultisigUsersViewController(content: .senders, threshold: sendersThreshold, users: senders)
        present(viewController, animated: true)
    }
    
    @objc private func showReceivers(_ sender: Any) {
        let viewController = MultisigUsersViewController(content: .receivers, threshold: receiversThreshold, users: receivers)
        present(viewController, animated: true)
    }
    
}

extension MultisigConfirmationViewController: AuthenticationIntent {
    
    var intentTitle: String {
        switch action {
        case .sign:
            return R.string.localizable.multisig_transaction()
        case .unlock:
            return R.string.localizable.revoke_multisig_transaction()
        }
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        ""
    }
    
    var options: AuthenticationIntentOptions {
        switch state {
        case .paid, .signed, .unlocked:
            return []
        case .pending:
            return [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
        }
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                let spendKey = try await TIP.spendPriv(pin: pin).hexEncodedString()
                Logger.general.info(category: "Multisig", message: "SpendKey ready")
                
                switch action {
                case .sign:
                    var error: NSError?
                    let signature = KernelSignTransaction(rawTransaction, viewKeys, spendKey, index, false, &error)
                    guard let signature, error == nil else {
                        throw Error.sign(error)
                    }
                    let request = TransactionRequest(id: requestID, raw: signature.raw)
                    _ = try await SafeAPI.signMultisigs(id: requestID, request: request)
                case .unlock:
                    _ = try await SafeAPI.unlockMultisigs(id: requestID)
                }
                
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    successView.doneButton.setTitle(R.string.localizable.done(), for: .normal)
                    successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    contentStackView.addArrangedSubview(successView)
                    view.layoutIfNeeded()
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "Multisig", message: "Failed to \(action): \(error)")
                let action: AuthenticationViewController.RetryAction
                switch error {
                case MixinAPIError.malformedPin, MixinAPIError.incorrectPin, MixinAPIError.insufficientPool, MixinAPIError.internalServerError:
                    action = .inputPINAgain
                case MixinAPIError.notRegisteredToSafe:
                    action = .notAllowed
                default:
                    action = .notAllowed
                }
                await MainActor.run {
                    completion(.failure(error: error, retry: action))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
