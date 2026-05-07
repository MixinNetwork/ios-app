import UIKit
import MixinServices

final class ShareObiView: UIView, XibDesignable {
    
    enum Content {
        case installMixin
        case referral(code: String, rebate: Decimal)
    }
    
    @IBOutlet weak var contentView: GradientView!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var textStackView: UIStackView!
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
    
    func load(gradient: Bool, content: Content) {
        if gradient {
            contentView.lightColors = [
                UIColor(displayP3RgbValue: 0x4B7CDD),
                UIColor(displayP3RgbValue: 0x81A4E7),
            ]
            contentView.darkColors = [
                UIColor(displayP3RgbValue: 0x3B448E),
                UIColor(displayP3RgbValue: 0x4C7DDE),
            ]
        } else {
            contentView.lightColors = nil
            contentView.darkColors = nil
        }
        switch content {
        case .installMixin:
            textStackView.spacing = 4
            titleLabel.text = .mixin
            descriptionLabel.text = R.string.localizable.install_messenger_desc()
            qrCodeView.setContent(
                URL.shortMixinMessenger.absoluteString,
                size: qrCodeView.bounds.size,
                activityIndicator: false
            )
        case let .referral(code, rebate):
            textStackView.spacing = 10
            titleLabel.attributedText = NSAttributedString(
                string: code,
                attributes: [
                    .foregroundColor: UIColor.white,
                    .font: UIFont.systemFont(
                        ofSize: 20,
                        weight: .accessiblityBoldTextCounterWeight(.semibold)
                    ),
                ],
            )
            descriptionLabel.attributedText = rebateDescription(rebate: rebate)
            qrCodeView.setContent(
                URL.bindReferral(code: code),
                size: qrCodeView.bounds.size,
                activityIndicator: false
            )
        }
    }
    
    private func rebateDescription(rebate: Decimal) -> NSAttributedString {
        if rebate >= 0.0001 {
            let rate = PercentageFormatter.string(
                from: rebate,
                format: .pretty,
                sign: .never
            )
            let description = NSMutableAttributedString(
                string: R.string.localizable.referral_share_desc(rate),
                attributes: [
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .font: UIFont.systemFont(
                        ofSize: 12,
                        weight: .accessiblityBoldTextCounterWeight(.regular)
                    ),
                ],
            )
            let rateRange = (description.string as NSString)
                .range(of: rate, options: .backwards)
            let rateAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(displayP3RgbValue: 0xFFEE70),
                .font: UIFont.systemFont(
                    ofSize: 12,
                    weight: .accessiblityBoldTextCounterWeight(.bold)
                ),
            ]
            description.setAttributes(rateAttributes, range: rateRange)
            return description
        } else {
            let description = NSMutableAttributedString(
                string: R.string.localizable.referral_share_desc_zero(),
                attributes: [
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .font: UIFont.systemFont(
                        ofSize: 12,
                        weight: .accessiblityBoldTextCounterWeight(.regular)
                    ),
                ],
            )
            return description
        }
    }
    
    private func loadSubviews() {
        loadXib()
        contentView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        contentView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        qrCodeView.layer.cornerCurve = .continuous
        qrCodeView.layer.cornerRadius = 6
        qrCodeView.layer.masksToBounds = true
    }
    
}
