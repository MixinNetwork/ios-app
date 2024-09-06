import UIKit

final class ShareMarketAsPictureView: UIView {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var obiView: UIView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var titleLabel: UILabel!
    
    private let obiBackgroundLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        obiBackgroundLayer.startPoint = CGPoint(x: 0, y: 0.5)
        obiBackgroundLayer.endPoint = CGPoint(x: 1, y: 0.5)
        obiView.layer.insertSublayer(obiBackgroundLayer, at: 0)
        updateObiColor()
        titleLabel.text = mixinMessenger
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 6
        qrCodeView.layer.masksToBounds = true
        qrCodeView.setContent(URL.shortMixinMessenger.absoluteString,
                              size: qrCodeView.bounds.size)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        obiBackgroundLayer.frame = obiView.bounds
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateObiColor()
        }
    }
    
    func setImage(_ image: UIImage) {
        imageView.image = image
        imageView.snp.remakeConstraints { make in
            let ratio = image.size.width / image.size.height
            make.width.equalTo(imageView.snp.height).multipliedBy(ratio).priority(.low)
        }
    }
    
    private func updateObiColor() {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            obiBackgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0x3B448E).cgColor,
                UIColor(displayP3RgbValue: 0x4C7DDE).cgColor,
            ]
        case .unspecified, .light:
            fallthrough
        @unknown default:
            obiBackgroundLayer.colors = [
                UIColor(displayP3RgbValue: 0x4B7CDD).cgColor,
                UIColor(displayP3RgbValue: 0x81A4E7).cgColor,
            ]
        }
    }
    
}
