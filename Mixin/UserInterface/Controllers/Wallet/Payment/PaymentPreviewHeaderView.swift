import UIKit
import MixinServices

final class PaymentPreviewHeaderView: UIView {
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private var assetIconView: AssetIconView?
    private var progressView: PaymentProgressView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                           adjustForContentSize: true)
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .regular),
                              adjustForContentSize: true)
    }
    
    func setIcon(token: TokenItem) {
        progressView?.removeFromSuperview()
        let iconView: AssetIconView
        if let view = self.assetIconView {
            iconView = view
        } else {
            iconView = AssetIconView()
            iconView.chainIconWidth = 23
            iconView.chainIconOutlineWidth = 0
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.assetIconView = iconView
        }
        iconView.setIcon(token: token)
    }
    
    func setIcon(progress: PaymentProgressView.Progress) {
        assetIconView?.removeFromSuperview()
        let progressView: PaymentProgressView
        if let view = self.progressView {
            progressView = view
        } else {
            progressView = PaymentProgressView()
            iconWrapperView.addSubview(progressView)
            progressView.snp.makeEdgesEqualToSuperview()
            self.progressView = progressView
        }
        progressView.setProgress(progress)
    }
    
}
