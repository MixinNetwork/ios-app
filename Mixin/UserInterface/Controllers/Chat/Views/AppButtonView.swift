import UIKit

final class AppButtonView: UIView {
    
    static let cornerRadius: CGFloat = 5
    static let buttonMargin = MessageViewModel.Margin(leading: 4, trailing: 4, top: 1, bottom: 3)
    static let titleMargin = MessageViewModel.Margin(leading: 14, trailing: 14, top: 8, bottom: 8)
    
    let button = UIButton(type: .system)
    
    private var disclosureIndicatorView: UIView?
    
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
    
    func setTitle(_ title: String, colorHexString: String, disclosureIndicator: Bool) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(hexString: colorHexString) ?? .gray, for: .normal)
        if disclosureIndicator {
            let indicator: UIView
            if let view = self.disclosureIndicatorView {
                view.isHidden = false
                indicator = view
            } else {
                indicator = UIImageView(image: R.image.external_indicator_arrow())
                indicator.tintColor = R.color.text_tertiary()
                addSubview(indicator)
                indicator.snp.makeConstraints { make in
                    make.top.equalTo(button).offset(6)
                    make.trailing.equalTo(button).offset(-6)
                }
                self.disclosureIndicatorView = indicator
            }
        } else {
            disclosureIndicatorView?.isHidden = true
        }
    }
    
    private func prepare() {
        button.backgroundColor = R.color.chat_button_background()
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
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 1
    }
    
}
