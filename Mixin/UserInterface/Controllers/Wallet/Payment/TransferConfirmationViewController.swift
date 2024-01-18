import UIKit
import MixinServices
import Tip

final class TransferConfirmationViewController: PaymentConfirmationViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: TransferPaymentOperation
    private let amountDisplay: AmountIntent
    private let tokenAmount: Decimal
    private let fiatMoneyAmount: Decimal
    private let redirection: URL?
    
    private var destination: Payment.TransferDestination {
        operation.destination
    }
    
    init(
        operation: TransferPaymentOperation,
        amountDisplay: AmountIntent,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        redirection: URL?
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.redirection = redirection
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch destination {
        case let .multisig(_, receivers):
            guard let account = LoginManager.shared.account else {
                break
            }
            insertMultisigPatternView { patternView in
                patternView.showSendersButton.addTarget(self, action: #selector(showSenders(_:)), for: .touchUpInside)
                patternView.showReceiversButton.addTarget(self, action: #selector(showReceivers(_:)), for: .touchUpInside)
                patternView.reloadData(senders: [UserItem.createUser(from: account)], receivers: receivers, action: .sign)
            }
        case .user, .mainnet:
            break
        }
        
        let token = operation.token
        assetIconView.setIcon(token: token)
        switch amountDisplay {
        case .byToken:
            amountLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
            valueLabel.text = CurrencyFormatter.estimatedFiatMoneyValue(amount: fiatMoneyAmount)
        case .byFiatMoney:
            amountLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .whenNegative) + " " + Currency.current.code
            valueLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
        }
        
        let memo = operation.memo
        if !memo.isEmpty {
            let memoLabel = UILabel()
            memoLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            memoLabel.textColor = .text
            memoLabel.numberOfLines = 0
            memoLabel.text = memo
            contentStackView.addArrangedSubview(memoLabel)
        }
    }
    
    @objc private func finish(_ sender: Any) {
        guard manipulateNavigationStackOnFinished else {
            authenticationViewController?.presentingViewController?.dismiss(animated: true)
            return
        }
        authenticationViewController?.presentingViewController?.dismiss(animated: true) { [destination] in
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            switch destination {
            case let .user(opponent):
                if viewControllers.lazy.compactMap({ $0 as? ConversationViewController }).first?.dataSource.ownerUser?.userId == opponent.userId {
                    while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
                        viewControllers.removeLast()
                    }
                } else {
                    if opponent.isCreatedByMessenger {
                        while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
                            viewControllers.removeLast()
                        }
                        viewControllers.append(ConversationViewController.instance(ownerUser: opponent))
                    } else if let container = viewControllers.last as? ContainerViewController, container.viewController is TransferOutViewController {
                        viewControllers.removeLast()
                    }
                }
                navigation.setViewControllers(viewControllers, animated: true)
            case .multisig, .mainnet:
                if let lastViewController = viewControllers.last as? ContainerViewController, lastViewController.viewController is TransferOutViewController {
                    viewControllers.removeLast()
                }
                navigation.setViewControllers(viewControllers, animated: true)
            }
        }
    }
    
    @objc private func gotoMerchant(_ sender: Any) {
        guard let redirection = redirection else {
            finish(sender)
            return
        }
        authenticationViewController?.presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.open(redirection)
        }
    }
    
    @objc private func showSenders(_ sender: Any) {
        switch destination {
        case .multisig:
            guard let account = LoginManager.shared.account else {
                break
            }
            let senders = MultisigUsersViewController(content: .senders, threshold: 1, users: [UserItem.createUser(from: account)])
            present(senders, animated: true)
        default:
            break
        }
    }
    
    @objc private func showReceivers(_ sender: Any) {
        switch destination {
        case let .multisig(threshold, receivers):
            let receivers = MultisigUsersViewController(content: .receivers, threshold: Int(threshold), users: receivers)
            present(receivers, animated: true)
        default:
            break
        }
    }
    
}

extension TransferConfirmationViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        switch destination {
        case let .user(opponent):
            return R.string.localizable.transfer_to(opponent.fullName)
        case .multisig:
            return R.string.localizable.multisig_transaction()
        case .mainnet:
            return R.string.localizable.transfer()
        }
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        switch destination {
        case let .user(opponent):
            return opponent.isCreatedByMessenger ? opponent.identityNumber : opponent.userId
        case .multisig:
            return ""
        case let .mainnet(address):
            return address
        }
    }
    
    var options: AuthenticationIntentOptions {
        var options: AuthenticationIntentOptions = [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
        if redirection != nil {
            options.insert(.neverRequestAddBiometricAuthentication)
        }
        switch destination {
        case .mainnet:
            options.insert(.multipleLineSubtitle)
        default:
            break
        }
        return options
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                try await operation.start(pin: pin)
                await MainActor.run {
                    completion(.success)
                    let successView = R.nib.paymentSuccessView(withOwner: nil)!
                    if redirection == nil {
                        successView.doneButton.setTitle(R.string.localizable.done(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    } else {
                        successView.doneButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                        successView.doneButton.addTarget(self, action: #selector(gotoMerchant(_:)), for: .touchUpInside)
                        let stayInMixinButton = successView.insertStayInMixinButtonIfNeeded()
                        stayInMixinButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    }
                    contentStackView.addArrangedSubview(successView)
                    view.layoutIfNeeded()
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "Transfer", message: "Failed to transfer: \(error)")
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
