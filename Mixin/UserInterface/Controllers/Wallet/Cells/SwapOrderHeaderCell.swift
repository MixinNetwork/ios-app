import UIKit
import MixinServices

final class SwapOrderHeaderCell: UITableViewCell {

    @IBOutlet weak var iconView: SwapIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var stateLabel: InsetLabel!
    @IBOutlet weak var actionView: PillActionView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        iconView.size = .large
        stateLabel.contentInset = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        stateLabel.layer.cornerRadius = 4
        stateLabel.layer.masksToBounds = true
        stateLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        actionView.actions = [
            "Swap Again",
            "Share Pair",
        ]
    }
    
    func load(order: SwapOrderItem) {
        iconView.setTokenIcon(pay: order.payIconURL, receive: order.receiveIconURL)
        symbolLabel.text = order.exchangingSymbolRepresentation
        stateLabel.text = order.state?.localizedString
        switch order.state {
        case .pending, .none:
            stateLabel.textColor = R.color.text_secondary()
            stateLabel.backgroundColor = R.color.button_background_disabled()
        case .success:
            stateLabel.textColor = R.color.market_green()
            stateLabel.backgroundColor = R.color.market_green()!.withAlphaComponent(0.2)
        case .failed, .refunded:
            stateLabel.textColor = R.color.market_red()
            stateLabel.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
        }
    }
    
}
