import UIKit

class DeviceTransferActionTableHeaderView: UIView {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    @IBOutlet weak var imageViewTopConstraint: ScreenHeightCompatibleLayoutConstraint!
    @IBOutlet weak var labelTopConstraint: ScreenHeightCompatibleLayoutConstraint!
    @IBOutlet weak var labelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelBottomConstraint: NSLayoutConstraint!
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelWidth = size.width
            - labelLeadingConstraint.constant
            - labelTrailingConstraint.constant
        let sizeToFitLabel = CGSize(width: labelWidth, height: UIView.layoutFittingExpandedSize.height)
        let textLabelHeight = label.sizeThatFits(sizeToFitLabel).height
        let height = imageViewTopConstraint.constant
            + (imageView.image?.size.height ?? 72)
            + labelTopConstraint.constant
            + textLabelHeight
            + labelBottomConstraint.constant
        return CGSize(width: size.width, height: ceil(height))
    }
    
}
