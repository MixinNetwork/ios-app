import UIKit
import MixinServices

final class OutputCell: UITableViewCell {
    
    @IBOutlet weak var idLabel: UILabel!
    @IBOutlet weak var hashLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    
    private let descriptionAttributes: [NSAttributedString.Key : Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
        .foregroundColor: R.color.text_tertiary()!
    ]
    
    override func awakeFromNib() {
        super.awakeFromNib()
        idLabel.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        hashLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        descriptionLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    }
    
    func load(output: Output, showAssetID: Bool) {
        idLabel.text = output.id
        hashLabel.text = output.transactionHash
        descriptionLabel.attributedText = {
            let description = NSMutableAttributedString(string: "\(output.sequence):", attributes: descriptionAttributes)
            
            let stateColor: UIColor
            switch Output.State(rawValue: output.state) {
            case .signed:
                stateColor = R.color.market_red()!
            case .unspent:
                stateColor = R.color.market_green()!
            default:
                stateColor = R.color.text_tertiary()!
            }
            var stateAttributes = descriptionAttributes
            stateAttributes[.foregroundColor] = stateColor
            let state = NSMutableAttributedString(string: output.state, attributes: stateAttributes)
            description.append(state)
            
            if showAssetID {
                let assetID = NSAttributedString(string: ":\(output.asset)", attributes: descriptionAttributes)
                description.append(assetID)
            }
            
            return description
        }()
        amountLabel.text = output.amount
    }
    
    func load(output: Web3Output, showAddress: Bool) {
        idLabel.text = output.id
        hashLabel.text = "\(output.transactionHash):\(output.outputIndex)"
        descriptionLabel.attributedText = {
            let description = NSMutableAttributedString(string: output.createdAt, attributes: descriptionAttributes)
            
            let stateColor: UIColor
            switch output.status.knownCase {
            case .signed:
                stateColor = R.color.market_red()!
            case .unspent:
                stateColor = R.color.market_green()!
            default:
                stateColor = R.color.text_tertiary()!
            }
            var stateAttributes = descriptionAttributes
            stateAttributes[.foregroundColor] = stateColor
            let state = NSMutableAttributedString(string: "\n" + output.status.rawValue, attributes: stateAttributes)
            description.append(state)
            
            if showAddress {
                let address = NSAttributedString(string: "\n" + output.address, attributes: descriptionAttributes)
                description.append(address)
            }
            
            return description
        }()
        amountLabel.text = output.amount
    }
    
}
