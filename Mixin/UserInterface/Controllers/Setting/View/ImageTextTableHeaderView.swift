import UIKit

final class ImageTextTableHeaderView: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: IntroTextView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    
    private var lastLayoutWidth: CGFloat?
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelWidth = size.width
            - textViewLeadingConstraint.constant
            - textViewTrailingConstraint.constant
        let sizeToFitText = CGSize(width: labelWidth, height: UIView.layoutFittingExpandedSize.height)
        let textViewHeight = textView.sizeThatFits(sizeToFitText).height
        let height = imageViewTopConstraint.constant
            + (imageView.image?.size.height ?? 68)
            + textViewTopConstraint.constant
            + textViewHeight
            + textViewBottomConstraint.constant
        return CGSize(width: size.width, height: ceil(height))
    }
    
    func sizeToFit(tableView: UITableView) {
        assert(tableView.tableHeaderView == self)
        let width = tableView.bounds.width
        guard width != lastLayoutWidth else {
            return
        }
        let sizeToFit = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
        let height = sizeThatFits(sizeToFit).height
        frame.size = CGSize(width: width, height: height)
        tableView.tableHeaderView = self
        lastLayoutWidth = width
    }
    
}
