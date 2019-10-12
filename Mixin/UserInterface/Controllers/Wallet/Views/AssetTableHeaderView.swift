import UIKit

class AssetTableHeaderView: InfiniteTopView {
    
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountTextView: UITextView!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    @IBOutlet weak var depositButton: BusyButton!
    @IBOutlet weak var transactionsHeaderView: UIView!
    
    @IBOutlet weak var assetIconViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewTrailingConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        amountTextView.textContainerInset = .zero
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let sizeToFit = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
        let layoutSize = systemLayoutSizeFitting(sizeToFit)
        return CGSize(width: size.width, height: layoutSize.height)
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        let amount: String
        if asset.balance == "0" {
            amount = "0\(currentDecimalSeparator)00"
            fiatMoneyValueLabel.text = "≈ $0\(currentDecimalSeparator)00"
        } else {
            amount = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never) ?? ""
            fiatMoneyValueLabel.text = asset.localizedFiatMoneyBalance
        }
        depositButton.isBusy = asset.destination.isEmpty
        let attributedAmount = attributedString(amount: amount, symbol: asset.symbol)
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
    }
    
    private func attributedString(amount: String, symbol: String) -> NSMutableAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "DINCondensed-Bold", size: 34)!,
            .foregroundColor: UIColor.darkText
        ]
        let str = NSMutableAttributedString(string: amount, attributes: attrs)
        let attachment = SymbolTextAttachment(text: symbol)
        str.append(NSAttributedString(attachment: attachment))
        return str
    }
    
    class SymbolTextAttachment: NSTextAttachment {
        
        let leadingMargin: CGFloat = 6
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        init(text: String) {
            super.init(data: nil, ofType: nil)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkText
            ]
            let str = NSAttributedString(string: text, attributes: attributes)
            let textSize = str.size()
            let canvasSize = CGSize(width: leadingMargin + textSize.width, height: textSize.height)
            UIGraphicsBeginImageContextWithOptions(canvasSize, false, UIScreen.main.scale)
            str.draw(at: CGPoint(x: leadingMargin, y: 0))
            self.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        }
        
        override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
            var bounds = super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: position, characterIndex: charIndex)
            bounds.origin.y = -2
            return bounds
        }
        
    }
    
}
