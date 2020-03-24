import UIKit

class PageControlView: UIView, XibDesignable {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var backgroundEffectView: UIVisualEffectView!
    @IBOutlet weak var separatorLineView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 88, height: 40)
    }
    
    var style: UserInterfaceStyle = .light {
        didSet {
            update()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
    private func update() {
        let isDark = style == .dark
        backgroundEffectView.effect = isDark ? .darkBlur : .extraLightBlur
        
        let tintColor: UIColor = isDark ? .white : UIColor(displayP3RgbValue: 0x2E2F31)
        moreButton.tintColor = tintColor
        dismissButton.tintColor = tintColor
        
        let outlineColor: UIColor = isDark
            ? UIColor.white.withAlphaComponent(0.1)
            : UIColor.black.withAlphaComponent(0.06)
        separatorLineView.backgroundColor = outlineColor
        backgroundView.layer.borderColor = outlineColor.cgColor
    }
    
}
