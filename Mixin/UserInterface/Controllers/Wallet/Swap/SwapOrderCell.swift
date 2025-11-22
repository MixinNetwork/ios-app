import UIKit
import MixinServices

final class SwapOrderCell: UICollectionViewCell {
    
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
    
    func load(viewModel: SwapOrderViewModel) {
        swapIconView.setTokenIcon(
            pay: viewModel.payToken?.iconURL,
            receive: viewModel.receiveToken?.iconURL
        )
        symbolLabel.text = viewModel.exchangingSymbolRepresentation
        dateLabel.text = viewModel.createdAtRepresentation
        payAmountLabel.text = viewModel.paying.amount
        typeLabel.text = viewModel.type.localizedDescription
        receiveAmountLabel.text = viewModel.receivings.map(\.amount).joined(separator: " ")
        stateLabel.text = viewModel.state.localizedDescription
        switch viewModel.state.knownCase {
        case .success:
            receiveAmountLabel.textColor = R.color.market_green()
            stateLabel.textColor = R.color.market_green()
        case .created, .pending, .none:
            receiveAmountLabel.textColor = R.color.text_tertiary()
            stateLabel.textColor = R.color.text_tertiary()
        case .failed, .cancelling, .cancelled, .expired:
            receiveAmountLabel.textColor = R.color.market_green()
            stateLabel.textColor = R.color.market_red()
        }
    }
    
}
