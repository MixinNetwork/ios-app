import UIKit

class NumberPadButton: UIControl, XibDesignable {
    
    @IBOutlet weak var button: HighlightableButton!
    
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
    
    @IBAction func touchUpInsideAction(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }
    
    @objc private func updateButtonBackground() {
        if UIScreen.main.isCaptured {
            button.highlightedColor = R.color.keyboard_button_background()!
        }else{
            button.highlightedColor = R.color.keyboard_button_highlighted()!
        }
    }
    
}
