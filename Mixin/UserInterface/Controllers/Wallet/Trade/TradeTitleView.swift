import UIKit
import MixinServices

final class TradeTitleView: WalletIdentifyingNavigationTitleView {
    
    private weak var tagLabel: UILabel!
    
    init(wallet: Wallet) {
        super.init(
            title: R.string.localizable.trade(),
            wallet: wallet
        )
        let tagLabel = InsetLabel()
        tagLabel.layer.cornerRadius = 4
        tagLabel.layer.masksToBounds = true
        tagLabel.layer.borderWidth = 1
        tagLabel.layer.borderColor = R.color.outline_primary()!
            .resolvedColor(with: traitCollection)
            .cgColor
        tagLabel.backgroundColor = R.color.background()
        tagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        tagLabel.textColor = R.color.text_tertiary()
        tagLabel.font = .preferredFont(forTextStyle: .caption1)
        tagLabel.adjustsFontForContentSizeCategory = true
        tagLabel.text = R.string.localizable.trade_lite()
        titleStackView.addArrangedSubview(tagLabel)
        self.tagLabel = tagLabel
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        tagLabel.layer.borderColor = R.color.outline_primary()!
            .resolvedColor(with: traitCollection)
            .cgColor
    }
    
}
