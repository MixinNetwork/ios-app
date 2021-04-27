import UIKit
import WebKit

class SharedMediaPostCell: UITableViewCell {
    
    static let labelHorizontalMargin: CGFloat = 13
    static let labelVerticalMargin: CGFloat = 18
    static let backgroundHorizontalMargin: CGFloat = 20
    static let backgroundVerticalMargin: CGFloat = 5
    
    @IBOutlet weak var solidBackgroundColoredView: SolidBackgroundColoredView!
    @IBOutlet weak var webView: WKWebView!
    
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
        let height = viewModel.webViewFrame.height
            + Self.labelVerticalMargin * 2
            + Self.backgroundVerticalMargin * 2
        return CGSize(width: targetSize.width, height: height)
    }
    
    func render(viewModel: PostMessageViewModel) {
        self.viewModel = viewModel
        webView.loadHTMLString(viewModel.html, baseURL: Bundle.main.bundleURL)
    }
    
}
