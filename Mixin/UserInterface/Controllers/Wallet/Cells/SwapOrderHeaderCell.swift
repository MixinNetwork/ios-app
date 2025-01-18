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
            R.string.localizable.swap_again(),
            R.string.localizable.share_pair(),
        ]
    }
    
    func load(order: SwapOrderItem) {
        iconView.setTokenIcon(pay: order.payIconURL, receive: order.receiveIconURL)
        symbolLabel.text = order.exchangingSymbolRepresentation
        stateLabel.text = order.state.localizedDescription
        switch order.state.knownCase {
        case .success:
            stateLabel.textColor = R.color.market_green()
            stateLabel.backgroundColor = R.color.market_green()!.withAlphaComponent(0.2)
        case .pending, .none:
            stateLabel.textColor = R.color.text_secondary()
            stateLabel.backgroundColor = R.color.button_background_disabled()
        case .refunded, .failed:
            stateLabel.textColor = R.color.market_red()
            stateLabel.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
        }
    }
    
}
