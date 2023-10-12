import UIKit
import Checkout3DS
import MixinServices

final class BuyingProcessViewController: UIViewController {
    
    enum Payment {
        case applePay(Result<CheckoutPayment, Error>)
        case card(PaymentCard)
    }
    
    private enum Status {
        case processing
        case success
        case failed
    }
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var detailsView: PaymentDetailsTableView!
    @IBOutlet weak var feeExplanationLabel: UILabel!
    
    private let payment: Payment
    private let refreshInterval: TimeInterval = 3
    
    private var order: BuyCryptoConfirmedOrder
    
    private lazy var checkout3DS = {
        let service = Checkout3DSService(environment: BuyCryptoConfig.checkout3DSEnvironment, appURL: nil)
        checkout3DSIfLoaded = service
        return service
    }()
    
    private weak var processView: UIView?
    private weak var applePayPaymentRefreshingTimer: Timer?
    private weak var checkout3DSIfLoaded: Checkout3DSService?
    
    init(order: BuyCryptoConfirmedOrder, payment: Payment) {
        self.order = order
        self.payment = payment
        let nib = R.nib.buyingProcessView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        checkout3DSIfLoaded?.cleanup()
        applePayPaymentRefreshingTimer?.invalidate()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        detailsView.loadPrice(with: order)
        detailsView.loadAmounts(with: order)
        switch payment {
        case .applePay(let result):
            detailsView.loadPaymentMethods(with: .applePay)
            switch result {
            case .success(let payment):
                switch payment.status {
                case .authorized:
                    reloadSubviews(with: .processing)
                    schedulePaymentRefreshingTimer(paymentID: payment.id)
                case .captured:
                    reloadSubviews(with: .success)
                case .declined:
                    reloadSubviews(with: .failed)
                }
            case .failure:
                reloadSubviews(with: .failed)
            }
        case .card(let card):
            detailsView.loadPaymentMethods(with: .card(card))
            reloadSubviews(with: .processing)
            placeOrder(order, card: card)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    @objc private func done(_ sender: Any) {
        popViewControllers(offsetToBuyingAmount: -1)
    }
    
    @objc private func switchPayment(_ sender: Any) {
        popViewControllers(offsetToBuyingAmount: 1)
    }
    
    @objc private func cancelOrder(_ sender: Any) {
        popViewControllers(offsetToBuyingAmount: 0)
    }
    
    private func popViewControllers(offsetToBuyingAmount offset: Int) {
        guard let navigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers
        let buyingAmountIndex = viewControllers.firstIndex { viewController in
            if let container = viewController as? ContainerViewController {
                return container.viewController is BuyingAmountViewController
            } else {
                return viewController is BuyingAmountViewController
            }
        }
        if let index = buyingAmountIndex {
            viewControllers.removeLast(viewControllers.count - index - offset - 1)
            navigationController.setViewControllers(viewControllers, animated: true)
        } else {
            navigationController.popViewController(animated: true)
        }
    }
    
    private func reloadSubviews(with status: Status) {
        processView?.removeFromSuperview()
        switch status {
        case .processing:
            iconImageView.image = R.image.wallet.ic_buying_pending()
            statusLabel.text = R.string.localizable.processing()
            let processingView = ProcessingView()
            view.addSubview(processingView)
            processingView.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.top.greaterThanOrEqualTo(feeExplanationLabel.snp.bottom).offset(20).priority(.required)
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-50).priority(.high)
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).priority(.required)
            }
            feeExplanationLabel.isHidden = false
            processView = processingView
        case .success:
            iconImageView.image = R.image.wallet.ic_buying_success()
            statusLabel.text = R.string.localizable.buy_success()
            let paying = order.formatter.fiatMoneyDisplayString(order.paymentAmount) + " " + order.paymentCurrency
            let receiving = order.formatter.assetDisplayString(order.assetAmount) + " " + order.asset.symbol
            descriptionLabel.text = R.string.localizable.buy_success_description(paying, receiving)
            let doneButton = RoundedButton(type: .system)
            doneButton.setTitle(R.string.localizable.done(), for: .normal)
            doneButton.setTitleColor(.white, for: .normal)
            doneButton.addTarget(self, action: #selector(done(_:)), for: .touchUpInside)
            doneButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 50, bottom: 12, right: 50)
            view.addSubview(doneButton)
            doneButton.snp.makeConstraints { make in
                make.top.greaterThanOrEqualTo(feeExplanationLabel.snp.bottom).offset(20).priority(.required)
                make.centerX.equalToSuperview()
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-72).priority(.high)
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).priority(.required)
            }
            feeExplanationLabel.isHidden = false
            processView = doneButton
        case .failed:
            iconImageView.image = R.image.wallet.ic_buying_failed()
            statusLabel.text = R.string.localizable.buy_failed()
            descriptionLabel.text = R.string.localizable.buy_failed_description()
            let failureView = FailureView()
            failureView.switchPaymentMethodButton.addTarget(self, action: #selector(switchPayment(_:)), for: .touchUpInside)
            failureView.cancelButton.addTarget(self, action: #selector(cancelOrder(_:)), for: .touchUpInside)
            view.addSubview(failureView)
            failureView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview().offset(20)
                make.trailing.lessThanOrEqualToSuperview().offset(-20)
                make.top.greaterThanOrEqualTo(feeExplanationLabel.snp.bottom).offset(20).priority(.required)
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-17).priority(.high)
                make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).priority(.required)
            }
            feeExplanationLabel.isHidden = true
            processView = failureView
        }
    }
    
}

// MARK: - Card Payment
extension BuyingProcessViewController {
    
    private func placeOrder(_ order: BuyCryptoConfirmedOrder, card: PaymentCard) {
        let refreshInterval = UInt64(self.refreshInterval)
        Task {
            do {
                // Create session
                let sessionRequest = CreateCheckoutSessionRequest(assetID: order.asset.assetId,
                                                                  instrumentID: card.instrumentID,
                                                                  scheme: card.scheme,
                                                                  amount: order.checkoutAmount,
                                                                  currency: order.paymentCurrency)
                var session = try await RouteAPI.createSession(with: sessionRequest)
                
                // 3DS
                let parameters = AuthenticationParameters(sessionID: session.id,
                                                          sessionSecret: session.secret,
                                                          scheme: session.scheme)
                let _ = try await withCheckedThrowingContinuation { continuation in
                    self.checkout3DS.authenticate(authenticationParameters: parameters, completion: { (result) in
                        continuation.resume(with: result)
                    })
                }
                
                // Wait until session is approved
            sessionLoop: while true {
                switch session.status {
                case .approved:
                    break sessionLoop
                case .pending, .processing:
                    try await Task.sleep(nanoseconds: refreshInterval * NSEC_PER_SEC)
                    session = try await RouteAPI.session(with: session.id)
                default:
                    Logger.general.error(category: "BuyingProcess", message: "Invalid session status: \(session.status)")
                }
            }
                
                // Payment
                let assetAmount = order.formatter.assetTransportString(order.assetAmount)
                let paymentRequest = CheckoutPaymentRequest(assetID: order.asset.assetId,
                                                            payment: .instrument(id: card.instrumentID, sessionID: session.id),
                                                            scheme: card.scheme,
                                                            amount: order.checkoutAmount,
                                                            assetAmount: assetAmount,
                                                            currency: order.paymentCurrency,
                                                            countryCode: order.phoneNumberRegionCode ?? "")
                var payment: CheckoutPayment = try await RouteAPI.createPayment(with: paymentRequest)
                while true {
                    switch payment.status {
                    case .authorized:
                        try await Task.sleep(nanoseconds: refreshInterval * NSEC_PER_SEC)
                        payment = try await RouteAPI.payment(with: payment.id)
                    case .captured:
                        await MainActor.run {
                            reloadSubviews(with: .success)
                            Logger.general.info(category: "BuyingProcess", message: "Buying succeed")
                        }
                        return
                    case .declined:
                        throw BuyingError.paymentDeclined
                    }
                }
            } catch let MixinAPIError.priceExpired(newPrice, newAssetAmount) {
                await MainActor.run {
                    let priceExpired = PriceExpiredViewController(order: order, newPrice: newPrice, newAssetAmount: newAssetAmount) { newOrder in
                        self.order = newOrder
                        self.detailsView.loadPrice(with: newOrder)
                        self.detailsView.loadAmounts(with: newOrder)
                        self.placeOrder(newOrder, card: card)
                        self.dismiss(animated: true)
                    } onCancel: {
                        self.dismiss(animated: true) {
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                    present(priceExpired, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.reloadSubviews(with: .failed)
                    Logger.general.error(category: "BuyingProcess", message: "\(error)")
                }
            }
        }
    }
    
}

// MARK: - Apple Pay Status Checking
extension BuyingProcessViewController {
    
    private func schedulePaymentRefreshingTimer(paymentID: String) {
        applePayPaymentRefreshingTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: false) { [weak self] timer in
            guard self != nil else {
                timer.invalidate()
                return
            }
            RouteAPI.payment(with: paymentID) { result in
                switch result {
                case .success(let payment):
                    switch payment.status {
                    case .authorized:
                        self?.schedulePaymentRefreshingTimer(paymentID: paymentID)
                    case .captured:
                        self?.reloadSubviews(with: .success)
                    case .declined:
                        self?.reloadSubviews(with: .failed)
                    }
                case .failure:
                    Logger.general.error(category: "BuyingProcess", message: "Failed")
                    self?.reloadSubviews(with: .failed)
                }
            }
        }
    }
    
}

extension BuyingProcessViewController {
    
    private class ProcessingView: UIStackView {
        
        private let activityIndicator = ActivityIndicatorView()
        private let label = UILabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            insertSubviews()
        }
        
        required init(coder: NSCoder) {
            super.init(coder: coder)
            insertSubviews()
        }
        
        func insertSubviews() {
            spacing = 8
            axis = .vertical
            
            activityIndicator.backgroundColor = .background
            activityIndicator.tintColor = .accessoryText
            addArrangedSubview(activityIndicator)
            
            label.textAlignment = .center
            label.text = R.string.localizable.processing()
            label.font = .scaledFont(ofSize: 14, weight: .regular)
            label.adjustsFontForContentSizeCategory = true
            addArrangedSubview(label)
        }
        
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            activityIndicator.startAnimating()
        }
        
    }
    
    private class FailureView: UIStackView {
        
        let switchPaymentMethodButton = RoundedButton(type: .system)
        let cancelButton = UIButton(type: .system)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            insertSubviews()
        }
        
        required init(coder: NSCoder) {
            super.init(coder: coder)
            insertSubviews()
        }
        
        func insertSubviews() {
            spacing = 8
            axis = .vertical
            
            switchPaymentMethodButton.setTitleColor(.white, for: .normal)
            switchPaymentMethodButton.setTitle(R.string.localizable.switch_payment_method(), for: .normal)
            switchPaymentMethodButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 25, bottom: 12, right: 25)
            if let label = switchPaymentMethodButton.titleLabel {
                label.font = .preferredFont(forTextStyle: .callout)
                label.adjustsFontForContentSizeCategory = true
            }
            addArrangedSubview(switchPaymentMethodButton)
            
            cancelButton.setTitle(R.string.localizable.cancel_order(), for: .normal)
            if let label = cancelButton.titleLabel {
                label.font = .preferredFont(forTextStyle: .callout)
                label.adjustsFontForContentSizeCategory = true
            }
            cancelButton.snp.makeConstraints { make in
                make.height.equalTo(44)
            }
            addArrangedSubview(cancelButton)
        }
        
    }
    
}
