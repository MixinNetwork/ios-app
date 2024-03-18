import UIKit

final class BulletDescriptionView: UIView {
    
    private let textView = IntroTextView()
    private let textViewInsets = UIEdgeInsets(top: 20, left: 30, bottom: 20, right: 30)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    private func loadSubviews() {
        textView.backgroundColor = R.color.background()
        textView.textAlignment = .left
        textView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16))
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = R.color.text()!
        textView.textDragInteraction?.isEnabled = false
        textView.isScrollEnabled = false
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
                .inset(textViewInsets)
                .priority(.almostRequired)
        }
    }
    
    func setText(preface: String, bulletLines: [String]) {
        let text = NSMutableAttributedString()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 18
        paragraphStyle.lineHeightMultiple = 1.2
        
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 16)),
            .foregroundColor: R.color.text()!,
            .paragraphStyle: paragraphStyle
        ]
        
        text.append(NSAttributedString(string: preface, attributes: defaultAttributes))
        
        let bulletParagraphStyle = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        bulletParagraphStyle.paragraphSpacing = 10
        bulletParagraphStyle.headIndent = 11
        
        var bulletAttributes = defaultAttributes
        bulletAttributes[.paragraphStyle] = bulletParagraphStyle
        
        let bullet = NSAttributedString(string: "\n\u{2022} ", attributes: bulletAttributes)
        for line in bulletLines {
            text.append(bullet)
            text.append(NSAttributedString(string: line, attributes: bulletAttributes))
        }
        
        textView.attributedText = NSAttributedString(attributedString: text)
    }
    
}
