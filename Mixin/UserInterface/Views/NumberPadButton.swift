import UIKit

class NumberPadButton: UIControl, XibDesignable {
    
    @IBOutlet weak var button: UIButton!
    
    @IBInspectable var number: Int = 0 {
        didSet {
            button.setTitle(String(number), for: .normal)
        }
    }
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
		self.setup()
    }
	
	private func setup() {
		loadXib()
        updateButtonBackground()
		NotificationCenter.default.addObserver(self, selector: #selector(updateButtonBackground), name: UIScreen.capturedDidChangeNotification, object: nil)
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
    
    @objc private func updateButtonBackground() {
		button.setBackgroundImage(R.color.keyboard_button_background()!.image, for: .normal)
		if UIScreen.main.isCaptured {
			button.setBackgroundImage(R.color.keyboard_button_background()!.image, for: .highlighted)
		}else{
			button.setBackgroundImage(R.color.keyboard_button_highlighted()!.image, for: .highlighted)
		}
    }
    
}
