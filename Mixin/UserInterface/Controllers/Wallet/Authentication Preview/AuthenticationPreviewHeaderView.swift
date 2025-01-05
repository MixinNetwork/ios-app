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
    private weak var multipleTokenIconView: MultipleTokenIconView?
    
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
        let iconView: MultipleTokenIconView
        if let view = self.multipleTokenIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = MultipleTokenIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.height.equalTo(70)
            }
            self.multipleTokenIconView = iconView
        }
        iconView.setIcon(sendToken: sendToken, receiveToken: receiveToken)
    }
    
    func setIcon(tokens: [TokenItem]) {
        let iconView: MultipleTokenIconView
        if let view = self.multipleTokenIconView, view.isDescendant(of: iconWrapperView) {
            iconView = view
        } else {
            for iconView in iconWrapperView.subviews {
                iconView.removeFromSuperview()
            }
            iconView = MultipleTokenIconView()
            iconWrapperView.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.height.equalTo(70)
            }
            self.multipleTokenIconView = iconView
        }
        iconView.setIcons(tokens: tokens)
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
    
    private final class MultipleTokenIconView: UIView {
        
        private typealias IconWrapperView = StackedIconWrapperView<PlainTokenIconView>
        
        private let stackView = UIStackView()
        
        private var wrapperViews: [IconWrapperView] = []
        
        private weak var addtionalCountLabel: UILabel?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        func setIcons(tokens: [TokenItem]) {
            if tokens.count > 3 {
                loadIconViews(count: 2) { _, wrapperView in
                    wrapperView.snp.makeConstraints { make in
                        make.width.equalTo(wrapperView.snp.height).offset(-16)
                    }
                }
                let label: UILabel
                if let l = addtionalCountLabel {
                    label = l
                } else {
                    let view = StackedIconWrapperView<UILabel>()
                    view.backgroundColor = .clear
                    label = view.iconView
                    label.backgroundColor = R.color.background_quaternary()
                    label.textColor = R.color.text_tertiary()
                    label.font = .systemFont(ofSize: 20)
                    label.textAlignment = .center
                    label.minimumScaleFactor = 0.1
                    label.layer.cornerRadius = 34
                    label.layer.masksToBounds = true
                    stackView.addArrangedSubview(view)
                    view.snp.makeConstraints { make in
                        make.size.equalTo(70)
                    }
                }
                label.text = "+\(tokens.count - 2)"
            } else {
                loadIconViews(count: tokens.count) { index, wrapperView in
                    let offset = index == tokens.count - 1 ? 0 : -16
                    wrapperView.snp.makeConstraints { make in
                        make.width.equalTo(wrapperView.snp.height).offset(offset)
                    }
                }
            }
            for (i, wrapperView) in wrapperViews.enumerated() {
                wrapperView.iconView.setIcon(token: tokens[i])
            }
        }
        
        func setIcon(sendToken: TokenItem, receiveToken: SwapToken) {
            loadIconViews(count: 2) { index, wrapperView in
                let offset = index == 1 ? 0 : -16
                wrapperView.snp.makeConstraints { make in
                    make.width.equalTo(wrapperView.snp.height).offset(offset)
                }
            }
            wrapperViews[0].iconView.setIcon(token: sendToken)
            wrapperViews[1].iconView.setIcon(token: receiveToken)
        }
        
        private func loadIconViews(count: Int, makeConstraints maker: (Int, IconWrapperView) -> Void) {
            guard wrapperViews.count != count else {
                return
            }
            for view in stackView.arrangedSubviews {
                view.removeFromSuperview()
            }
            wrapperViews = []
            for i in 0..<count {
                let view = IconWrapperView()
                view.backgroundColor = .clear
                stackView.addArrangedSubview(view)
                wrapperViews.append(view)
                maker(i, view)
            }
        }
        
        private func loadSubviews() {
            backgroundColor = R.color.background()
            addSubview(stackView)
            stackView.snp.makeEdgesEqualToSuperview()
        }
        
    }
    
}
