import UIKit

final class SwapOpenOrderCell: UICollectionViewCell {
    
    @IBOutlet weak var swapIconView: SwapIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var payAmountLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var receiveAmountLabel: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let labels: [UILabel] = [
            dateLabel,
            payAmountLabel,
            typeLabel,
            receiveAmountLabel,
            stateLabel
        ]
        for label in labels {
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        swapIconView.prepareForReuse()
    }
    
    func load(order: LimitOrder) {
//        swapIconView.setTokenIcon(pay: order.payIconURL, receive: order.receiveIconURL)
//        symbolLabel.text = order.exchangingSymbolRepresentation
//        if let date = order.createdAtDate {
//            dateLabel.text = DateFormatter.dateFull.string(from: date)
//        } else {
//            dateLabel.text = order.createdAt
//        }
//        payAmountLabel.text = CurrencyFormatter.localizedString(
//            from: -order.payAmount,
//            format: .precision,
//            sign: .always,
//            symbol: .custom(order.paySymbol)
//        )
//        typeLabel.text = order.type.localizedDescription
//        receiveAmountLabel.text = order.actualReceivingAmount
//        stateLabel.text = order.state.localizedDescription
//        switch order.state.knownCase {
//        case .success:
//            receiveAmountLabel.textColor = R.color.market_green()
//            stateLabel.textColor = R.color.market_green()
//        case .pending, .none:
//            receiveAmountLabel.textColor = R.color.text_tertiary()
//            stateLabel.textColor = R.color.text_tertiary()
//        case .failed:
//            receiveAmountLabel.textColor = R.color.market_green()
//            stateLabel.textColor = R.color.market_red()
//        }
    }
    
}
