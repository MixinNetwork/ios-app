import UIKit
import PassKit
import Frames
import Checkout3DS
import MixinServices

final class BuyingOrderPreviewViewController: UIViewController {
    
    private class PeriodicTickerIndicatorView: ActivityIndicatorView {
        
        override var lineWidth: CGFloat {
            1
        }
        
        override var contentLength: CGFloat {
            11
        }
        
    }
    
    private enum ApplePayResult {
        case success(CheckoutPayment)
        case priceExpired(newPrice: Decimal, newAssetAmount: Decimal)
        case failure(Error)
    }
    
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var assetAmountLabel: UILabel!
    @IBOutlet weak var detailsView: PaymentDetailsTableView!
    @IBOutlet weak var feeExplanationLabel: UILabel!
    
    private let initialOrder: BuyCryptoOrder
    private let payment: PaymentSource
    private let tickerUpdateInterval: Int = 9
    private let countdownLabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .monospacedDigitSystemFont(ofSize: 14, weight: .regular))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.theme()
        return label
    }()
    
    private var confirmingOrder: BuyCryptoConfirmedOrder?
    private var applePayResult: ApplePayResult?
    private var tickerCounter = 0
    
    private lazy var feePercentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()
    
    private weak var countdownStackView: UIStackView!
    private weak var periodicTickerLoadingIndicator: ActivityIndicatorView!
    private weak var buyButton: UIButton!
    
    private weak var tickerTimer: Timer?
    private weak var initialTickerLoadingIndicator: ActivityIndicatorView?
    
    init(order: BuyCryptoOrder, payment: PaymentSource) {
        self.initialOrder = order
        self.payment = payment
        let nib = R.nib.buyingOrderPreviewView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let countdownImageView = UIImageView(image: R.image.wallet.price_countdown())
        countdownImageView.contentMode = .center
        countdownImageView.setContentHuggingPriority(.required, for: .horizontal)
        countdownImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        countdownLabel.textAlignment = .right
        countdownLabel.setContentHuggingPriority(.required, for: .horizontal)
        countdownLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let countdownStackView = UIStackView(arrangedSubviews: [countdownImageView, countdownLabel])
        countdownStackView.axis = .horizontal
        countdownStackView.alignment = .center
        countdownStackView.spacing = 4
        countdownStackView.isHidden = true
        detailsView.priceStackView.insertArrangedSubview(countdownStackView, at: 1)
        self.countdownStackView = countdownStackView
        
        let periodicTickerLoadingIndicator = PeriodicTickerIndicatorView()
        periodicTickerLoadingIndicator.tintColor = UIColor(displayP3RgbValue: 0xBDBDBD)
        periodicTickerLoadingIndicator.hidesWhenStopped = true
        periodicTickerLoadingIndicator.isAnimating = false
        detailsView.priceStackView.insertArrangedSubview(periodicTickerLoadingIndicator, at: 2)
        periodicTickerLoadingIndicator.snp.makeConstraints { make in
            make.width.equalTo(periodicTickerLoadingIndicator.contentLength + 1)
        }
        self.periodicTickerLoadingIndicator = periodicTickerLoadingIndicator
        
        assetIconView.setIcon(asset: initialOrder.asset)
        assetAmountLabel.text = "+" + initialOrder.receivedString
        assetAmountLabel.alpha = 0
        detailsView.loadPaymentMethods(with: payment)
        detailsView.loadPrice(with: initialOrder)
        
        let buyButton: UIButton
        switch payment {
        case .applePay:
            let style: PKPaymentButtonStyle
            if #available(iOS 14.0, *) {
                style = .automatic
            } else {
                style = .black
            }
            let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: style)
            button.addTarget(self, action: #selector(buyWithApplePay(_:)), for: .touchUpInside)
            button.cornerRadius = button.intrinsicContentSize.height / 2
            button.alpha = 0
            buyButton = button
        case .card:
            let button = RoundedButton(type: .system)
            button.setTitleColor(.white, for: .normal)
            button.setTitle(R.string.localizable.buy_asset(initialOrder.asset.symbol), for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 26, bottom: 12, right: 26)
            button.addTarget(self, action: #selector(buyWithCard(_:)), for: .touchUpInside)
            button.isEnabled = false
            buyButton = button
        }
        view.addSubview(buyButton)
        buyButton.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(feeExplanationLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.height.equalTo(42)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-80).priority(.low)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-8)
            if case .applePay = payment {
                make.width.equalTo(buyButton.intrinsicContentSize.width + 32)
            }
        }
        self.buyButton = buyButton
        
        if case .applePay = payment {
            let indicator = ActivityIndicatorView()
            indicator.tintColor = R.color.text_desc()
            view.addSubview(indicator)
            indicator.snp.makeConstraints { make in
                make.center.equalTo(buyButton)
            }
            indicator.startAnimating()
            self.initialTickerLoadingIndicator = indicator
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        Logger.general.debug(category: "BuyingOrderPreview", message: "View will appear")
        updateTicker()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Logger.general.debug(category: "BuyingOrderPreview", message: "View will disappear")
        invalidateTickerTimer()
    }
    
    @objc private func buyWithCard(_ button: RoundedButton) {
        let placeOrder = PlaceOrderViewController()
        placeOrder.onApprove = {
            guard let order = self.confirmingOrder, case let .card(card) = self.payment else {
                return
            }
            self.invalidateTickerTimer()
            let process = BuyingProcessViewController(order: order, payment: .card(card))
            self.navigationController?.pushViewController(process, animated: true)
        }
        let authentication = AuthenticationViewController(intentViewController: placeOrder)
        present(authentication, animated: true)
    }
    
    @objc private func buyWithApplePay(_ sender: Any) {
        let placeOrder = PlaceOrderViewController()
        placeOrder.onApprove = {
            guard let order = self.confirmingOrder else {
                return
            }
            self.invalidateTickerTimer()
            self.authorizePayment(with: order)
        }
        let authentication = AuthenticationViewController(intentViewController: placeOrder)
        present(authentication, animated: true)
    }
    
    private func authorizePayment(with order: BuyCryptoConfirmedOrder) {
        applePayResult = nil
        
        let asset = PKPaymentSummaryItem(
            label: order.asset.symbol,
            amount: NSDecimalNumber(decimal: order.ticker.purchase),
            type: .final
        )
        let feeByGateway = PKPaymentSummaryItem(
            label: R.string.localizable.fees_by_gateway(),
            amount: NSDecimalNumber(decimal: order.ticker.feeByGateway),
            type: .final
        )
        let feeByMixin = PKPaymentSummaryItem(
            label: R.string.localizable.fees_by_mixin(),
            amount: NSDecimalNumber(decimal: order.ticker.feeByMixin),
            type: .final
        )
        let total = PKPaymentSummaryItem(
            label: "Mixin",
            amount: NSDecimalNumber(decimal: order.ticker.totalAmount),
            type: .final
        )
        
        let request = PKPaymentRequest()
        request.paymentSummaryItems = [asset, feeByGateway, feeByMixin, total]
        request.merchantIdentifier = BuyCryptoConfig.applePayMerchantID
        request.merchantCapabilities = .capability3DS
        request.countryCode = "PL"
        request.currencyCode = order.paymentCurrency
        request.supportedNetworks = BuyCryptoConfig.applePayNetworks
        request.shippingType = .delivery
        request.shippingMethods = nil
        request.requiredShippingContactFields = []
        
        let authorization = PKPaymentAuthorizationController(paymentRequest: request)
        authorization.delegate = self
        authorization.present(completion: { (presented: Bool) in
            if presented {
                Logger.general.info(category: "BuyingOrderPreview", message: "Payment controller presented")
            } else {
                Logger.general.error(category: "BuyingOrderPreview", message: "Payment controller not presented")
                showAutoHiddenHud(style: .error, text: "Unable to present")
            }
        })
    }
    
    private func invalidateTickerTimer() {
        tickerTimer?.invalidate()
        tickerCounter = 0
        countdownLabel.text = nil
    }
    
    private func scheduleTickerTimer() {
        invalidateTickerTimer()
        CATransaction.performWithoutAnimation {
            countdownStackView.isHidden = false
            periodicTickerLoadingIndicator.stopAnimating()
        }
        countdownLabel.text = "\(tickerUpdateInterval)s"
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.tickerCounter += 1
            if self.tickerCounter == self.tickerUpdateInterval {
                timer.invalidate()
                self.tickerCounter = 0
                self.updateTicker()
                CATransaction.performWithoutAnimation {
                    self.countdownStackView.isHidden = true
                    self.periodicTickerLoadingIndicator.startAnimating()
                }
            } else {
                self.countdownLabel.text = "\(self.tickerUpdateInterval - self.tickerCounter)s"
            }
        }
    }
    
    private func updateTicker() {
        let initialOrder = self.initialOrder
        RouteAPI.ticker(amount: initialOrder.checkoutAmount, assetID: initialOrder.asset.assetId, currency: initialOrder.paymentCurrency) { [weak self] ticker in
            switch ticker {
            case .success(let ticker):
                if let self {
                    let order = BuyCryptoConfirmedOrder(confirmedTicker: ticker, order: initialOrder)
                    self.assetAmountLabel.text = "+" + order.receivedString
                    self.assetAmountLabel.alpha = 1
                    self.detailsView.loadPrice(with: order)
                    self.detailsView.loadAmounts(with: order)
                    self.confirmingOrder = order
                    self.buyButton?.alpha = 1
                    if let button = self.buyButton as? RoundedButton {
                        button.isEnabled = true
                    }
                    if let indicator = self.initialTickerLoadingIndicator {
                        indicator.stopAnimating()
                        indicator.removeFromSuperview()
                    }
                    self.scheduleTickerTimer()
                }
            case .failure(let error):
                Logger.general.error(category: "BuyingOrderPreview", message: "\(error)")
                self?.updateTicker()
            }
        }
    }
    
}

extension BuyingOrderPreviewViewController: PKPaymentAuthorizationControllerDelegate {
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            DispatchQueue.main.async {
                guard let result = self.applePayResult, let confirmedOrder = self.confirmingOrder else {
                    self.scheduleTickerTimer()
                    return
                }
                switch result {
                case let .success(payment):
                    let process = BuyingProcessViewController(order: confirmedOrder, payment: .applePay(.success(payment)))
                    self.navigationController?.pushViewController(process, animated: true)
                case let .priceExpired(newPrice, newAssetAmount):
                    let priceExpired = PriceExpiredViewController(order: confirmedOrder, newPrice: newPrice, newAssetAmount: newAssetAmount) { newOrder in
                        self.confirmingOrder = newOrder
                        self.assetAmountLabel.text = "+" + newOrder.receivedString
                        self.detailsView.loadPrice(with: newOrder)
                        self.detailsView.loadAmounts(with: newOrder)
                        self.authorizePayment(with: newOrder)
                        self.dismiss(animated: true)
                    } onCancel: {
                        self.scheduleTickerTimer()
                        self.dismiss(animated: true)
                    }
                    self.present(priceExpired, animated: true)
                case let .failure(error):
                    let process = BuyingProcessViewController(order: confirmedOrder, payment: .applePay(.failure(error)))
                    self.navigationController?.pushViewController(process, animated: true)
                }
            }
        }
    }
    
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let order = confirmingOrder else {
            completion(.init(status: .failure, errors: nil))
            return
        }
        let assetAmount = order.formatter.assetTransportString(order.assetAmount)
        let token = String(data: payment.token.paymentData, encoding: .utf8)!
        RouteAPI.createToken(withApplePayToken: token) { result in
            switch result {
            case .failure(let error):
                self.applePayResult = .failure(error)
                completion(.init(status: .failure, errors: [error]))
            case .success(let token):
                guard token.tokenFormat == "cryptogram_3ds" else {
                    let error: BuyingError = .invalidTokenFormat
                    self.applePayResult = .failure(error)
                    completion(.init(status: .failure, errors: [error]))
                    return
                }
                let request = CheckoutPaymentRequest(assetID: order.asset.assetId,
                                                     payment: .token(token.token),
                                                     scheme: token.scheme,
                                                     amount: order.checkoutAmount,
                                                     assetAmount: assetAmount,
                                                     currency: order.paymentCurrency)
                RouteAPI.createPayment(with: request) { result in
                    switch result {
                    case .success(let payment):
                        self.applePayResult = .success(payment)
                        completion(.init(status: .success, errors: nil))
                    case .failure(let error):
                        switch error {
                        case let .priceExpired(price, assetAmount):
                            self.applePayResult = .priceExpired(newPrice: price, newAssetAmount: assetAmount)
                        default:
                            self.applePayResult = .failure(error)
                        }
                        completion(.init(status: .failure, errors: [error]))
                    }
                }
            }
        }
    }
    
}
