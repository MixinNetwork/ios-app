import UIKit
import MixinServices

final class TokenTableHeaderView: InfiniteTopView {
    
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    @IBOutlet weak var disclosureImageView: UIImageView!
    @IBOutlet weak var tokenInfoButton: UIButton!
    @IBOutlet weak var transferActionView: PillActionView!
    @IBOutlet weak var transactionsHeaderView: UIView!
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var assetIconViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewTrailingConstraint: NSLayoutConstraint!
    
    private var token: TokenItem?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountTextView.textContainerInset = .zero
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sizeToFit = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
        let layoutSize = systemLayoutSizeFitting(sizeToFit)
        return CGSize(width: size.width, height: layoutSize.height)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection), let token {
            render(token: token)
        }
    }
    
    func render(token: TokenItem) {
        assetIconView.setIcon(token: token)
        let amount: String
        if token.balance == "0" {
            amount = zeroWith2Fractions
            fiatMoneyValueLabel.text = "≈ $0\(currentDecimalSeparator)00"
        } else {
            amount = CurrencyFormatter.localizedString(from: token.balance, format: .precision, sign: .never) ?? ""
            fiatMoneyValueLabel.text = token.localizedFiatMoneyBalance
        }
        let attributedAmount = attributedString(amount: amount, symbol: token.symbol)
        amountTextView.attributedText = attributedAmount
        
        let range = NSRange(location: 0, length: attributedAmount.length)
        var lineCount = 0
        var lastLineGlyphCount = 0
        amountTextView.layoutManager.enumerateLineFragments(forGlyphRange: range) { (rect, usedRect, textContainer, glyphRange, stop) in
            lastLineGlyphCount = glyphRange.length
            lineCount += 1
        }
        let minGlyphCountOfLastLine = 4 // 3 digits and 1 asset symbol
        if lineCount > 1 && lastLineGlyphCount < minGlyphCountOfLastLine {
            let linebreak = NSAttributedString(string: "\n")
            attributedAmount.insert(linebreak, at: attributedAmount.length - minGlyphCountOfLastLine)
            amountTextView.attributedText = attributedAmount
        }
        
        if token.collectionHash == nil {
            disclosureImageView.isHidden = false
            tokenInfoButton.isEnabled = true
        } else {
            disclosureImageView.isHidden = true
            tokenInfoButton.isEnabled = false
        }
        self.token = token
    }
    
    private func attributedString(amount: String, symbol: String) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFontMetrics.default.scaledFont(for: .condensed(size: 34)),
            .foregroundColor: UIColor.text
        ]
        let str = NSMutableAttributedString(string: amount, attributes: attrs)
        let attachment = SymbolTextAttachment(text: symbol)
        str.append(NSAttributedString(attachment: attachment))
        return str
    }
    
}
