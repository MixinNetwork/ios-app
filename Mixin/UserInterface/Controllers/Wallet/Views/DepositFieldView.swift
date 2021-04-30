import UIKit

protocol DepositFieldViewDelegate: AnyObject {
    func depositFieldViewDidCopyContent(_ view: DepositFieldView)
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView)
}

class DepositFieldView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var shadowView: SeparatorShadowView!
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentSpacingConstraint: NSLayoutConstraint!
    
    weak var delegate: DepositFieldViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
        updateScreenSizeBasedConstraints()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        updateScreenSizeBasedConstraints()
    }
    
    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = contentLabel.text
        delegate?.depositFieldViewDidCopyContent(self)
    }
    
    @IBAction func showQRCodeAction(_ sender: Any) {
        delegate?.depositFieldViewDidSelectShowQRCode(self)
    }
    
    private func updateScreenSizeBasedConstraints() {
        guard ScreenWidth.current <= .short else {
            return
        }
        contentLeadingConstraint.constant = 20
        contentTrailingConstraint.constant = 20
        contentSpacingConstraint.constant = 16
    }
    
}
