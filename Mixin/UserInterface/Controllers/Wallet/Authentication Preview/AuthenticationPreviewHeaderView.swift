import UIKit
import MixinServices

final class AuthenticationPreviewHeaderView: UIView {
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private weak var imageView: UIImageView?
    private weak var assetIconView: AssetIconView?
    private weak var progressView: AuthenticationProgressView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                           adjustForContentSize: true)
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 14, weight: .regular),
                              adjustForContentSize: true)
    }
    
    func setIcon(setter: (UIImageView) -> Void) {
        if let imageView, imageView.isDescendant(of: iconWrapperView) {
            setter(imageView)
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            let imageView = UIImageView()
            iconWrapperView.addSubview(imageView)
            imageView.snp.makeEdgesEqualToSuperview()
            setter(imageView)
            self.imageView = imageView
        }
    }
    
    func setIcon(token: TokenItem) {
        let iconView: AssetIconView
        if let view = self.assetIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = AssetIconView()
            iconView.chainIconWidth = 23
            iconView.chainIconOutlineWidth = 0
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.assetIconView = iconView
        }
        iconView.setIcon(token: token)
    }
    
    func setIcon(progress: AuthenticationProgressView.Progress) {
        let progressView: AuthenticationProgressView
        if let view = self.progressView, view.isDescendant(of: iconWrapperView) {
            progressView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            progressView = AuthenticationProgressView()
            iconWrapperView.addSubview(progressView)
            progressView.snp.makeEdgesEqualToSuperview()
            self.progressView = progressView
        }
        progressView.setProgress(progress)
    }
    
}
