import UIKit

final class ShareObiView: UIView, XibDesignable {
    
    @IBOutlet weak var contentView: GradientView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    private func loadSubviews() {
        loadXib()
        contentView.lightColors = [
            UIColor(displayP3RgbValue: 0x4B7CDD),
            UIColor(displayP3RgbValue: 0x81A4E7),
        ]
        contentView.darkColors = [
            UIColor(displayP3RgbValue: 0x3B448E),
            UIColor(displayP3RgbValue: 0x4C7DDE),
        ]
        contentView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        contentView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        titleLabel.text = .mixin
        descriptionLabel.text = R.string.localizable.install_messenger_desc()
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 6
        qrCodeView.layer.masksToBounds = true
        qrCodeView.setContent(
            URL.shortMixinMessenger.absoluteString,
            size: qrCodeView.bounds.size,
            activityIndicator: false
        )
    }
    
}
