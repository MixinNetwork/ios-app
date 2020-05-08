import UIKit

class AppButtonView: UIView {
    
    static let cornerRadius: CGFloat = 8
    static let buttonMargin = MessageViewModel.Margin(leading: 5, trailing: 5, top: 1, bottom: 3)
    static let titleMargin = MessageViewModel.Margin(leading: 16, trailing: 16, top: 10, bottom: 12)
    
    let button = AppButton()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    static func boundingSize(with width: CGFloat, title: String) -> CGSize {
        let boundingSize = CGSize(width: width - Self.buttonMargin.horizontal - Self.titleMargin.horizontal,
                                  height: UIView.layoutFittingExpandedSize.height)
        let titleAttributes = [NSAttributedString.Key.font: MessageFontSet.appButtonTitle.scaled]
        let titleRect = (title as NSString).boundingRect(with: boundingSize,
                                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                         attributes: titleAttributes,
                                                         context: nil)
        return CGSize(width: ceil(titleRect.width + Self.titleMargin.horizontal + Self.buttonMargin.horizontal),
                      height: ceil(titleRect.height + Self.titleMargin.vertical + Self.buttonMargin.vertical))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = CGRect(x: Self.buttonMargin.leading,
                              y: Self.buttonMargin.top,
                              width: bounds.width - Self.buttonMargin.horizontal,
                              height: bounds.height - Self.buttonMargin.vertical)
        layer.shadowPath = CGPath(roundedRect: button.frame,
                                  cornerWidth: Self.cornerRadius,
                                  cornerHeight: Self.cornerRadius,
                                  transform: nil)
    }
    
    func setTitle(_ title: String, colorHexString: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(hexString: colorHexString) ?? .gray, for: .normal)
    }
    
    private func prepare() {
        if let label = button.titleLabel {
            label.numberOfLines = 0
            label.font = MessageFontSet.appButtonTitle.scaled
            label.adjustsFontForContentSizeCategory = true
            label.lineBreakMode = .byCharWrapping
        }
        button.layer.cornerRadius = Self.cornerRadius
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: AppButtonView.titleMargin.top,
                                                left: AppButtonView.titleMargin.leading,
                                                bottom: AppButtonView.titleMargin.bottom,
                                                right: AppButtonView.titleMargin.trailing)
        addSubview(button)
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 1
    }
    
}
