import UIKit

final class ShareMarketAsPictureView: UIView {
    
    // Manipulating UIImage to render on CGContext is quite cumbersome, and the behavior varies
    // across different iOS versions. Therefore, an invisible view is used to capture a screenshot
    // to generate the image for sharing.
    
    @IBOutlet weak var screenshotWrapperView: UIView!
    @IBOutlet weak var screenshotImageView: UIImageView!
    @IBOutlet weak var displayImageView: UIImageView!
    @IBOutlet weak var obiView: GradientView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        obiView.lightColors = [
            UIColor(displayP3RgbValue: 0x4B7CDD),
            UIColor(displayP3RgbValue: 0x81A4E7),
        ]
        obiView.darkColors = [
            UIColor(displayP3RgbValue: 0x3B448E),
            UIColor(displayP3RgbValue: 0x4C7DDE),
        ]
        obiView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        obiView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        titleLabel.text = mixinMessenger
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 6
        qrCodeView.layer.masksToBounds = true
        qrCodeView.setContent(
            URL.shortMixinMessenger.absoluteString,
            size: qrCodeView.bounds.size,
            activityIndicator: false
        )
    }
    
    func setImage(_ image: UIImage) {
        let ratio = image.size.width / image.size.height
        screenshotImageView.image = image
        screenshotImageView.snp.makeConstraints { make in
            make.width.equalTo(screenshotImageView.snp.height).multipliedBy(ratio)
        }
        displayImageView.image = image
        displayImageView.snp.remakeConstraints { make in
            make.width.equalTo(displayImageView.snp.height).multipliedBy(ratio).priority(.low)
        }
    }
    
}
