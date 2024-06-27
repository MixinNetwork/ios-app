import UIKit
import MixinServices

final class AuthenticationPreviewHeaderView: UIView {
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private weak var imageView: UIImageView?
    private weak var assetIconView: BadgeIconView?
    private weak var progressView: AuthenticationProgressView?
    private weak var textContentView: TextInscriptionContentView?
    
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
            imageView.layer.cornerRadius = 35
            imageView.layer.masksToBounds = true
            iconWrapperView.addSubview(imageView)
            imageView.snp.makeEdgesEqualToSuperview()
            setter(imageView)
            self.imageView = imageView
        }
    }
    
    func setIcon(token: TokenItem) {
        let iconView: BadgeIconView
        if let view = self.assetIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = BadgeIconView()
            iconView.badgeIconDiameter = 23
            iconView.badgeOutlineWidth = 0
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
    
    func setIcon(collectionIconURL: URL, textContentURL: URL) {
        let imageView: UIImageView
        if let view = self.imageView, view.isDescendant(of: iconWrapperView) {
            imageView = view
            imageView.sd_cancelCurrentImageLoad()
        } else {
            imageView = UIImageView()
            imageView.layer.cornerRadius = 12
            imageView.layer.masksToBounds = true
            iconWrapperView.addSubview(imageView)
            imageView.snp.makeEdgesEqualToSuperview()
            self.imageView = imageView
        }
        imageView.image = R.image.collectible_text_background()
        
        let textContentView: TextInscriptionContentView
        if let view = self.textContentView, view.isDescendant(of: iconWrapperView) {
            textContentView = view
            textContentView.prepareForReuse()
        } else {
            textContentView = TextInscriptionContentView(iconDimension: 40, spacing: 4)
            textContentView.label.numberOfLines = 1
            textContentView.label.font = .systemFont(ofSize: 8, weight: .semibold)
            iconWrapperView.addSubview(textContentView)
            textContentView.snp.makeConstraints { make in
                let inset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
                make.edges.equalToSuperview().inset(inset)
            }
            self.textContentView = textContentView
        }
        textContentView.reloadData(collectionIconURL: collectionIconURL,
                                   textContentURL: textContentURL)
        
        for view in iconWrapperView.subviews {
            if view != imageView && view != textContentView {
                view.removeFromSuperview()
            }
        }
    }
    
}
