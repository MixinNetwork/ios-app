import UIKit

final class WatchlistRecommendationActionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func watchlistRecommendationActionCellDidInvokeAction(_ cell: WatchlistRecommendationActionCell)
    }
    
    @IBOutlet weak var actionButton: ConfigurationBasedBusyButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        actionButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.add_to_watchlist(),
            textStyle: .callout
        )
    }
    
    @IBAction func invokeAction(_ sender: Any) {
        delegate?.watchlistRecommendationActionCellDidInvokeAction(self)
    }
    
}
