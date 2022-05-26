import UIKit

class TopResultCell: UITableViewCell {
    
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    private var prefixAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.text]
    }
    
    private var contentAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.theme]
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
    
    func setText(number: String) {
        setText(prefix: R.string.localizable.search_placeholder_number(), content: number)
    }
    
    func setText(link: String) {
        setText(prefix: R.string.localizable.search_open_link(), content: link)
    }
    
    private func setText(prefix: String, content: String) {
        let attributedText = NSMutableAttributedString(string: prefix, attributes: prefixAttributes)
        attributedText.append(NSAttributedString(string: content, attributes: contentAttributes))
        label.attributedText = attributedText
    }
    
}
