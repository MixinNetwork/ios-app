import UIKit
import Combine
import Alamofire
import MixinServices

final class QuickAccessResultCell: UITableViewCell {
    
    @IBOutlet weak var topShadowView: TopShadowView!
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    private var busyObserver: AnyCancellable?
    
    private var prefixAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.text]
    }
    
    private var contentAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.theme]
    }
    
    var result: QuickAccessSearchResult? {
        didSet {
            switch result?.content {
            case let .number(number):
                setText(prefix: R.string.localizable.search_placeholder_number(), content: number)
            case let .link(_, verbatim):
                setText(prefix: R.string.localizable.search_open_link(), content: verbatim)
            case .none:
                break
            }
            busyObserver?.cancel()
            if let result {
                busyObserver = result.$isBusy.sink() { [weak activityIndicator] busy in
                    activityIndicator?.isAnimating = busy
                }
            }
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let color: UIColor = highlighted ? .selectionBackground : .background
        let work = {
            self.labelBackgroundView.backgroundColor = color
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
    }
    
    private func setText(prefix: String, content: String) {
        let attributedText = NSMutableAttributedString(string: prefix, attributes: prefixAttributes)
        attributedText.append(NSAttributedString(string: content, attributes: contentAttributes))
        label.attributedText = attributedText
    }
    
}
