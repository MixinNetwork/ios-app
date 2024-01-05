import UIKit
import MixinServices
import Tip

final class WithdrawalConfirmationViewController: PaymentConfirmationViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: WithdrawPaymentOperation
    
    private let amountDisplay: AmountIntent
    private let withdrawalTokenAmount: Decimal
    private let withdrawalFiatMoneyAmount: Decimal
    private let addressLabel: String?
    
    init(
        operation: WithdrawPaymentOperation,
        amountDisplay: AmountIntent,
        withdrawalTokenAmount: Decimal,
        withdrawalFiatMoneyAmount: Decimal,
        addressLabel: String?
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        self.withdrawalTokenAmount = withdrawalTokenAmount
        self.withdrawalFiatMoneyAmount = withdrawalFiatMoneyAmount
        self.addressLabel = addressLabel
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let withdrawalToken = operation.withdrawalToken
        let feeAmount = operation.feeAmount
        let feeToken = operation.feeToken
        assetIconView.setIcon(token: withdrawalToken)
        
        let tokenAmount = CurrencyFormatter.localizedString(from: withdrawalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
        switch amountDisplay {
        case .byToken:
            amountLabel.text = tokenAmount
        case .byFiatMoney:
            amountLabel.text = CurrencyFormatter.localizedString(from: withdrawalFiatMoneyAmount, format: .fiatMoney, sign: .whenNegative, symbol: .currentCurrency)
        }
        
        let fiatMoneyAmount = CurrencyFormatter.estimatedFiatMoneyValue(amount: withdrawalFiatMoneyAmount)
        let fee = CurrencyFormatter.localizedString(from: feeAmount, format: .precision, sign: .never, symbol: .custom(feeToken.symbol))
        let feeValue = CurrencyFormatter.estimatedFiatMoneyValue(amount: feeAmount * feeToken.decimalUSDPrice * Decimal(Currency.current.rate))
        valueLabel.text = R.string.localizable.pay_withdrawal_memo(tokenAmount, fiatMoneyAmount, fee, feeValue)
    }
    
    @objc private func finish(_ sender: Any) {
        guard manipulateNavigationStackOnFinished else {
            authenticationViewController?.presentingViewController?.dismiss(animated: true)
            return
        }
        authenticationViewController?.presentingViewController?.dismiss(animated: true) {
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
                if let _ = (viewControllers.last as? ContainerViewController)?.viewController as? TokenViewController {
                    break
                }
                viewControllers.removeLast()
            }
            navigation.setViewControllers(viewControllers, animated: true)
        }
    }
    
}

extension WithdrawalConfirmationViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        if let addressLabel {
            return R.string.localizable.withdrawal_to(addressLabel)
        } else {
            return R.string.localizable.withdrawal()
        }
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        operation.address.fullRepresentation
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear]
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
                    successView.doneButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                    contentStackView.addArrangedSubview(successView)
                    authenticationViewController?.endPINInputting()
                    UIDevice.current.playPaymentSuccess()
                }
            } catch {
                Logger.general.error(category: "Withdraw", message: "Failed to withdraw: \(error)")
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
