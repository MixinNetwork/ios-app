import UIKit
import MixinServices

final class AuthenticationPreviewHeaderView: UIView {
    
    enum Style {
        case plain
        case insetted(margin: CGFloat)
    }
    
    @IBOutlet weak var iconWrapperView: UIView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleTextView: UITextView!
    
    @IBOutlet weak var titleStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleStackViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorLineHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var separatorLineBottomConstraint: NSLayoutConstraint!
    
    var style: Style = .plain {
        didSet {
            layout(style: style)
        }
    }
    
    private weak var backgroundView: UIView?
    private weak var imageView: UIImageView?
    private weak var assetIconView: BadgeIconView?
    private weak var progressView: AuthenticationProgressView?
    private weak var textContentView: TextInscriptionContentView?
    private weak var multipleTokenIconView: StackedTokenIconView?
    
    private weak var backgroundViewTopConstraint: NSLayoutConstraint?
    private weak var backgroundViewLeadingConstraint: NSLayoutConstraint?
    private weak var backgroundViewTrailingConstraint: NSLayoutConstraint?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 18, weight: .medium),
                           adjustForContentSize: true)
        subtitleTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        subtitleTextView.adjustsFontForContentSizeCategory = true
        subtitleTextView.textContainerInset = .zero
        subtitleTextView.textContainer.lineFragmentPadding = 0
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
    
    func setIcon(token: MixinTokenItem) {
        let iconView: BadgeIconView
        if let view = self.assetIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = BadgeIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.assetIconView = iconView
        }
        iconView.badgeIconDiameter = 23
        iconView.badgeOutlineWidth = 0
        iconView.setIcon(token: token)
    }
    
    func setIcon(token: any OnChainToken) {
        let iconView: BadgeIconView
        if let view = self.assetIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = BadgeIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.assetIconView = iconView
        }
        iconView.badgeIconDiameter = 23
        iconView.badgeOutlineWidth = 0
        iconView.setIcon(token: token, chain: token.chain)
    }
    
    func setIcon(chain: Chain) {
        let iconView: BadgeIconView
        if let view = self.assetIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = BadgeIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeEdgesEqualToSuperview()
            self.assetIconView = iconView
        }
        iconView.setIcon(chain: chain)
    }
    
    func setIcon(sendToken: Token, receiveToken: SwapToken) {
        let iconView: StackedTokenIconView
        if let view = self.multipleTokenIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = StackedTokenIconView()
            iconView.size = .large
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.height.equalTo(70)
            }
            self.multipleTokenIconView = iconView
        }
        iconView.setIcon(sendToken: sendToken, receiveToken: receiveToken)
    }
    
    func setIcon(tokens: [MixinTokenItem]) {
        let iconView: StackedTokenIconView
        if let view = self.multipleTokenIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = StackedTokenIconView()
            iconView.size = .large
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.height.equalTo(70)
            }
            self.multipleTokenIconView = iconView
        }
        iconView.setIcons(urls: tokens.map(\.iconURL))
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
    
    private func layout(style: Style) {
        switch style {
        case .plain:
            backgroundColor = R.color.background()
            backgroundView?.removeFromSuperview()
            titleStackViewLeadingConstraint.constant = 38
            titleStackViewTrailingConstraint.constant = 38
            separatorLineHeightConstraint.constant = 10
            separatorLineBottomConstraint.constant = 10
        case .insetted(let margin):
            backgroundColor = R.color.background_quaternary()
            if backgroundView == nil {
                let backgroundView = UIView()
                backgroundView.backgroundColor = R.color.background()
                backgroundView.layer.cornerRadius = 8
                backgroundView.layer.masksToBounds = true
                insertSubview(backgroundView, at: 0)
                backgroundView.snp.makeConstraints { make in
                    make.bottom.equalToSuperview().offset(-10)
                }
                let backgroundViewTopConstraint = backgroundView.topAnchor
                    .constraint(equalTo: topAnchor, constant: margin)
                let backgroundViewLeadingConstraint = backgroundView.leadingAnchor
                    .constraint(equalTo: leadingAnchor, constant: margin)
                let backgroundViewTrailingConstraint = backgroundView.trailingAnchor
                    .constraint(equalTo: trailingAnchor, constant: -margin)
                NSLayoutConstraint.activate([
                    backgroundViewTopConstraint,
                    backgroundViewLeadingConstraint,
                    backgroundViewTrailingConstraint
                ])
                self.backgroundView = backgroundView
                self.backgroundViewTopConstraint = backgroundViewTopConstraint
                self.backgroundViewLeadingConstraint = backgroundViewLeadingConstraint
                self.backgroundViewTrailingConstraint = backgroundViewTrailingConstraint
            }
            backgroundViewTopConstraint?.constant = margin
            backgroundViewLeadingConstraint?.constant = margin
            backgroundViewTrailingConstraint?.constant = -margin
            titleStackViewLeadingConstraint.constant = margin + 16
            titleStackViewTrailingConstraint.constant = margin + 16
            separatorLineHeightConstraint.constant = 0
            separatorLineBottomConstraint.constant = 2
        }
    }
    
}
