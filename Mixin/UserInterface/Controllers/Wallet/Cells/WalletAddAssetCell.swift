import UIKit

class WalletAddAssetCell: UITableViewCell {
    
    static let height: CGFloat = 90
    
    private let dashOutlineLayer = CAShapeLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.insertSublayer(dashOutlineLayer, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        dashOutlineLayer.frame = bounds
        let dashOutlineVerticalMargin: CGFloat = 5
        let dashOutlineHorizontalMargin: CGFloat = 10
        let roundedRect = CGRect(x: bounds.origin.x + dashOutlineHorizontalMargin,
                                 y: bounds.origin.y + dashOutlineVerticalMargin,
                                 width: bounds.width - dashOutlineHorizontalMargin * 2,
                                 height: bounds.height - dashOutlineVerticalMargin * 2)
        dashOutlineLayer.path = CGPath(roundedRect: roundedRect,
                                       cornerWidth: 8,
                                       cornerHeight: 8,
                                       transform: nil)
        dashOutlineLayer.strokeColor = UIColor(rgbValue: 0xD5E3F9).cgColor
        dashOutlineLayer.lineWidth = 1
        dashOutlineLayer.lineDashPattern = [3, 3]
        dashOutlineLayer.fillColor = UIColor.white.cgColor
    }
    
}
