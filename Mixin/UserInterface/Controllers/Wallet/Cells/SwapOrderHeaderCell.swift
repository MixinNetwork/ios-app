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
    }
    
    func load(viewModel: SwapOrderViewModel) {
        iconView.setTokenIcon(pay: viewModel.payToken?.iconURL, receive: viewModel.receiveToken?.iconURL)
        symbolLabel.text = viewModel.exchangingSymbolRepresentation
        stateLabel.text = viewModel.state.localizedDescription
        switch viewModel.state.knownCase {
        case .success:
            stateLabel.textColor = R.color.market_green()
            stateLabel.backgroundColor = R.color.market_green()!.withAlphaComponent(0.2)
        case .created, .pending, .none:
            stateLabel.textColor = R.color.text_secondary()
            stateLabel.backgroundColor = R.color.button_background_disabled()
        case .failed, .cancelling, .cancelled, .expired:
            stateLabel.textColor = R.color.market_red()
            stateLabel.backgroundColor = R.color.market_red()!.withAlphaComponent(0.2)
        }
    }
    
}
