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
    private weak var swapIconView: SwapIconView?
    
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
    
    func setIcon(sendToken: TokenItem, receiveToken: SwapToken) {
        let iconView: SwapIconView
        if let view = self.swapIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = SwapIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(124)
                make.height.equalTo(70)
            }
            self.swapIconView = iconView
        }
        iconView.setIcon(sendToken: sendToken, receiveToken: receiveToken)
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

extension AuthenticationPreviewHeaderView {
    
    private final class SwapIconView: UIView {
        
        private let sendIconView = UIImageView()
        private let borderProviderView = UIView()
        private let receiveIconView = UIImageView()
        private let borderWidth: CGFloat = 2
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            sendIconView.layer.cornerRadius = sendIconView.frame.width / 2
            borderProviderView.layer.cornerRadius = borderProviderView.frame.width / 2
            receiveIconView.layer.cornerRadius = receiveIconView.frame.width / 2
        }
        
        func setIcon(sendToken: TokenItem, receiveToken: SwapToken) {
            sendIconView.sd_setImage(with: URL(string: sendToken.iconURL),
                                     placeholderImage: nil,
                                     context: assetIconContext)
            receiveIconView.sd_setImage(with: receiveToken.iconURL,
                                        placeholderImage: nil,
                                        context: assetIconContext)
        }
        
        private func loadSubviews() {
            sendIconView.layer.masksToBounds = true
            addSubview(sendIconView)
            sendIconView.snp.makeConstraints { make in
                make.top.leading.equalToSuperview().offset(borderWidth)
                make.bottom.equalToSuperview().offset(-borderWidth)
                make.width.equalTo(sendIconView.snp.height)
            }
            
            borderProviderView.backgroundColor = R.color.background()
            borderProviderView.layer.masksToBounds = true
            addSubview(borderProviderView)
            borderProviderView.snp.makeConstraints { make in
                make.top.trailing.bottom.equalToSuperview()
                make.width.equalTo(borderProviderView.snp.height)
            }
            
            receiveIconView.layer.masksToBounds = true
            addSubview(receiveIconView)
            receiveIconView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(borderWidth)
                make.trailing.bottom.equalToSuperview().offset(-borderWidth)
                make.width.equalTo(receiveIconView.snp.height)
            }
        }
        
    }
    
}
