import UIKit

class NumberPadButton: UIControl, XibDesignable {
    
    @IBOutlet weak var button: UIButton!
    
    @IBInspectable var number: Int = 0 {
        didSet {
            button.setTitle(String(number), for: .normal)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
        updateButtonBackground()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        updateButtonBackground()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard #available(iOS 12.0, *), traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
            return
        }
        updateButtonBackground()
    }
    
    @IBAction func touchUpInsideAction(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }
    
    private func updateButtonBackground() {
        button.setBackgroundImage(R.color.keyboard_button_background()!.image, for: .normal)
        button.setBackgroundImage(R.color.keyboard_button_highlighted()!.image, for: .highlighted)
    }
    
}
