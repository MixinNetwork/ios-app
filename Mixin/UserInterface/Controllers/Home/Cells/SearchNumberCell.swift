import UIKit

class SearchNumberCell: UITableViewCell {
    
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    private var numberAttributes: [NSAttributedString.Key: Any] {
        return [.font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: UIColor.theme]
    }
    
    private var prefix: NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.text
        ]
        let plain = R.string.localizable.search_placeholder_number()
        let str = NSAttributedString(string: plain, attributes: attrs)
        return str
    }
    
    var number: String? {
        didSet {
            let text = NSMutableAttributedString(attributedString: prefix)
            text.append(NSMutableAttributedString(string: number ?? "", attributes: numberAttributes))
            label.attributedText = text
        }
    }
    
    var isBusy = false {
        didSet {
            activityIndicator.isAnimating = isBusy
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
    
}
