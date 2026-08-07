import UIKit

final class WatchlistRecommendationFooterView: UICollectionReusableView {
    
    protocol Delegate: AnyObject {
        func watchlistRecommendationFooterViewDidInvokeAction(_ footerView: WatchlistRecommendationFooterView)
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
        delegate?.watchlistRecommendationFooterViewDidInvokeAction(self)
    }
    
}
