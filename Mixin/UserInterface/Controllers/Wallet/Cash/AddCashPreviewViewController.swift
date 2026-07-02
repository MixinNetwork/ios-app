import UIKit
import MixinServices

final class AddCashPreviewViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var payTitleLabel: UILabel!
    @IBOutlet weak var payContentLabel: UILabel!
    @IBOutlet weak var feeTitleLabel: UILabel!
    @IBOutlet weak var feeContentLabel: UILabel!
    @IBOutlet weak var trayWrapperView: UIView!
    @IBOutlet weak var errorDescriptionLabel: InsetLabel!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
    private let account: CashAccount
    private let addingAmount: Decimal
    private let operation: TransferPaymentOperation
    private let presentationManager = PopupPresentationManager()
    
    private weak var doubleButtonTrayView: AuthenticationPreviewDoubleButtonTrayView?
    
    init(
        account: CashAccount,
        addingAmount: Decimal,
        operation: TransferPaymentOperation,
    ) {
        self.account = account
        self.addingAmount = addingAmount
        self.operation = operation
        let nib = R.nib.addCashPreviewView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = presentationManager
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 13
        backgroundView.layer.cornerRadius = 8
        backgroundView.layer.masksToBounds = true
        titleView.backgroundColor = R.color.background_quaternary()
        titleView.titleLabel.text = R.string.localizable.cash_account_add_cash()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        amountLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .medium),
            adjustForContentSize: true
        )
        let additionalValue = CurrencyFormatter.localizedString(
            from: addingAmount,
            format: .fiatMoneyPrecision,
            sign: .always,
            symbol: .custom(Currency.usd.code)
        )
        amountLabel.text = additionalValue
        descriptionLabel.attributedText = {
            let afterValue = CurrencyFormatter.localizedString(
                from: account.decimalBalance + addingAmount,
                format: .fiatMoneyPrecision,
                sign: .never,
                symbol: .custom(Currency.usd.code)
            )
            let text = NSMutableAttributedString(
                string: R.string.localizable.cash_account_preview_description(additionalValue, afterValue),
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                    .foregroundColor: R.color.text()!,
                ]
            )
            let numberRanges = [
                text.mutableString.range(of: additionalValue),
                text.mutableString.range(of: afterValue),
            ].filter { range in
                range.location != NSNotFound && range.length != 0
            }
            for range in numberRanges {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14, weight: .medium)),
                    .foregroundColor: R.color.market_green()!,
                ]
                text.setAttributes(attributes, range: range)
            }
            return text
        }()
        let infoLabels: [UILabel] = [
            payTitleLabel,
            payContentLabel,
            feeTitleLabel,
            feeContentLabel,
        ]
        for label in infoLabels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
        payTitleLabel.text = R.string.localizable.pay_with_biometry_type("")
        payContentLabel.text = R.string.localizable.cash_account_preview_pay_with_value(
            operation.amount.formatted(),
            operation.token.symbol,
            "",
            addingAmount.formatted(
                Decimal.FormatStyle.Currency
                    .currency(code: Currency.usd.code)
                    .presentation(.narrow)
                    .rounded(rule: .towardZero)
            )
        )
        feeTitleLabel.text = R.string.localizable.fee()
        feeContentLabel.text = Decimal(0).formatted(
            Decimal.FormatStyle.Currency
                .currency(code: Currency.usd.code)
                .presentation(.narrow)
                .rounded(rule: .towardZero)
        )
        errorDescriptionLabel.contentInset = UIEdgeInsets(top: 16, left: 36, bottom: 0, right: 36)
        errorDescriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        let trayView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
        trayView.backgroundColor = R.color.background_quaternary()
        UIView.performWithoutAnimation {
            trayView.leftButton.setTitle(R.string.localizable.cancel(), for: .normal)
            trayView.leftButton.layoutIfNeeded()
            trayView.rightButton.setTitle(R.string.localizable.confirm(), for: .normal)
            trayView.rightButton.layoutIfNeeded()
        }
        trayWrapperView.addSubview(trayView)
        trayView.snp.makeEdgesEqualToSuperview()
        trayView.leftButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        trayView.rightButton.addTarget(self, action: #selector(confirm(_:)), for: .touchUpInside)
        self.doubleButtonTrayView = trayView
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func confirm(_ sender: Any) {
        let intent = PreviewedAuthenticationIntent(onInput: pay(with:))
        let authentication = AuthenticationViewController(intent: intent)
        present(authentication, animated: true)
    }
    
    private func pay(with pin: String) {
        titleView.closeButton.alpha = 0
        errorDescriptionLabel.text = nil
        doubleButtonTrayView?.alpha = 0
        activityIndicatorView.startAnimating()
        updatePreferredContentSizeHeight()
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    titleView.closeButton.alpha = 1
                    activityIndicatorView.stopAnimating()
                    doubleButtonTrayView?.removeFromSuperview()
                    let doneTrayView = AuthenticationPreviewSingleButtonTrayView()
                    doneTrayView.backgroundColor = R.color.background_quaternary()
                    doneTrayView.button.configuration?.title = R.string.localizable.done()
                    trayWrapperView.addSubview(doneTrayView)
                    doneTrayView.button.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                    doneTrayView.snp.makeEdgesEqualToSuperview()
                }
            } catch {
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    titleView.closeButton.alpha = 1
                    activityIndicatorView.stopAnimating()
                    errorDescriptionLabel.text = errorDescription
                    doubleButtonTrayView?.rightButton.setTitle(R.string.localizable.retry(), for: .normal)
                    doubleButtonTrayView?.alpha = 1
                    updatePreferredContentSizeHeight()
                }
            }
        }
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let width = view.bounds.width
        let fittingSize = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        preferredContentSize.height = view.systemLayoutSizeFitting(fittingSize).height
    }
    
}
