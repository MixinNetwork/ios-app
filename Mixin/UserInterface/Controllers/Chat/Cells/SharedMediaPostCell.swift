import UIKit

class SharedMediaPostCell: UITableViewCell {
    
    static let labelHorizontalMargin: CGFloat = 13
    static let labelVerticalMargin: CGFloat = 18
    static let backgroundHorizontalMargin: CGFloat = 20
    static let backgroundVerticalMargin: CGFloat = 5
    
    @IBOutlet weak var solidBackgroundColoredView: SolidBackgroundColoredView!
    @IBOutlet weak var label: TextMessageLabel!
    
    @IBOutlet weak var labelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var backgroundLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var backgroundBottomConstraint: NSLayoutConstraint!
    
    private var viewModel: PostMessageViewModel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        labelLeadingConstraint.constant = Self.labelHorizontalMargin
        labelTrailingConstraint.constant = Self.labelHorizontalMargin
        labelTopConstraint.constant = Self.labelVerticalMargin
        labelBottomConstraint.constant = Self.labelVerticalMargin
        backgroundLeadingConstraint.constant = Self.backgroundHorizontalMargin
        backgroundTrailingConstraint.constant = Self.backgroundHorizontalMargin
        backgroundTopConstraint.constant = Self.backgroundVerticalMargin
        backgroundBottomConstraint.constant = Self.backgroundVerticalMargin
        solidBackgroundColoredView.backgroundColorIgnoringSystemSettings = .secondaryBackground
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        }()
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        guard let viewModel = viewModel else {
            return super.systemLayoutSizeFitting(targetSize,
                                                 withHorizontalFittingPriority: horizontalFittingPriority,
                                                 verticalFittingPriority: verticalFittingPriority)
        }
        let height = viewModel.contentLabelFrame.height
            + Self.labelVerticalMargin * 2
            + Self.backgroundVerticalMargin * 2
        return CGSize(width: targetSize.width, height: height)
    }
    
    func render(viewModel: PostMessageViewModel) {
        self.viewModel = viewModel
        label.content = viewModel.content
        label.setNeedsDisplay()
    }
    
}
