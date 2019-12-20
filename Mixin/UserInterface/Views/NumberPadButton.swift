import UIKit

class NumberPadButton: UIControl, XibDesignable {


    static let normalBackgroundImage = R.color.keyboard_button_background()!.image
    static let highlightedBackgroundImage = R.color.keyboard_button_highlighted()!.image
    
    @IBOutlet weak var button: UIButton!
    
    @IBInspectable var number: Int = 0 {
        didSet {
            button.setTitle(String(number), for: .normal)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    @IBAction func touchUpInsideAction(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }
    
    private func prepare() {
        loadXib()
        button.setBackgroundImage(NumberPadButton.normalBackgroundImage, for: .normal)
        button.setBackgroundImage(NumberPadButton.highlightedBackgroundImage, for: .highlighted)
    }

}
