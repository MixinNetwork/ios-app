import UIKit
import MixinServices

final class TradeTitleView: WalletIdentifyingNavigationTitleView {
    
    private weak var tagBackgroundView: UIView!
    
    init(wallet: Wallet) {
        super.init(
            title: R.string.localizable.trade(),
            wallet: wallet
        )
        
        let tagBackgroundView = UIView()
        tagBackgroundView.backgroundColor = R.color.background()
        tagBackgroundView.layer.cornerRadius = 4
        tagBackgroundView.layer.masksToBounds = true
        tagBackgroundView.layer.borderWidth = 1
        tagBackgroundView.layer.borderColor = R.color.outline_primary()!
            .resolvedColor(with: traitCollection)
            .cgColor
        titleStackView.addArrangedSubview(tagBackgroundView)
        self.tagBackgroundView = tagBackgroundView
        
        let tagLabel = UILabel()
        tagLabel.backgroundColor = .clear
        tagLabel.textColor = R.color.text_tertiary()
        tagLabel.font = .preferredFont(forTextStyle: .caption1)
        tagLabel.adjustsFontForContentSizeCategory = true
        tagLabel.text = R.string.localizable.trade_lite()
        tagBackgroundView.addSubview(tagLabel)
        tagLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
                .inset(UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4))
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tagBackgroundView.layer.borderColor = R.color.outline_primary()!
            .resolvedColor(with: traitCollection)
            .cgColor
    }
    
}
