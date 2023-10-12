import UIKit

final class PaymentDetailsTableView: UIView, XibDesignable {
    
    @IBOutlet weak var priceStackView: UIStackView!
    
    @IBOutlet weak var paymentMethodImageView: UIImageView!
    @IBOutlet weak var paymentMethodLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var tokenAmountLabel: UILabel!
    @IBOutlet weak var feeByGatewayAmountLabel: UILabel!
    @IBOutlet weak var feeByMixinAmountLabel: UILabel!
    @IBOutlet weak var totalAmountLabel: UILabel!
    
    // Works for `XibDesignable`
    let contentEdgeInsets = UIEdgeInsets(top: 22, left: 16, bottom: 22, right: 16)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
    func loadPaymentMethods(with payment: PaymentSource) {
        switch payment {
        case .applePay:
            paymentMethodImageView.image = R.image.wallet.apple_pay_compact()
            paymentMethodLabel.text = "Apple Pay"
        case .card(let card):
            paymentMethodImageView.image = card.schemeImage
            paymentMethodLabel.text = card.scheme.capitalized + "..." + card.postfix
        }
    }
    
    func loadPrice(with order: BuyCryptoOrder) {
        priceLabel.text = order.priceString
    }
    
    func loadAmounts(with order: BuyCryptoOrder) {
        tokenAmountLabel.text = order.receivedString
        feeByGatewayAmountLabel.text = order.feeByGatewayAmountString
        feeByMixinAmountLabel.text = order.feeByMixinAmountString
        totalAmountLabel.text = order.totalAmountString
    }
    
}
