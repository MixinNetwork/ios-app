import UIKit

class SearchNumberCell: UITableViewCell {
    
    @IBOutlet weak var labelBackgroundView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    private let numberAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 14),
        .foregroundColor: UIColor.highlightedText
    ]
    
    private let prefix: NSAttributedString = {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkText
        ]
        let plain = R.string.localizable.search_placeholder_number()
        let str = NSAttributedString(string: plain, attributes: attrs)
        return str
    }()
    
    var isBusy = false {
        didSet {
            activityIndicator.isAnimating = isBusy
            label.isHidden = isBusy
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let color: UIColor = highlighted ? .modernCellSelection : .white
        let work = {
            self.labelBackgroundView.backgroundColor = color
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
    }
    
    func render(number: String) {
        let text = NSMutableAttributedString(attributedString: prefix)
        text.append(NSMutableAttributedString(string: number, attributes: numberAttributes))
        label.attributedText = text
    }
    
}
