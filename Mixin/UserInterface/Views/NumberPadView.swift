import UIKit
import MixinServices

class NumberPadView: UIView, XibDesignable {

    @IBOutlet weak var tipView: UIView!
    
    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var tipViewHeightConstraint: NSLayoutConstraint!
    
    weak var target: UIKeyInput?
    
    private let contentBottomMargin: CGFloat = 2
    
    private var contentHeight: CGFloat {
        switch ScreenHeight.current {
        case .short, .medium, .long:
            246
        case .extraLong:
            256
        }
    }
    
    private var bottomSafeAreaInset: CGFloat {
        let safeAreaBottomInset = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        if safeAreaBottomInset > 0 {
            switch ScreenHeight.current {
            case .short, .medium:
                return 58
            case .long, .extraLong:
                return 75
            }
        } else {
            return 0
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: bounds.width, height: contentHeight + bottomSafeAreaInset)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }

    @IBAction func inputAction(_ sender: Any) {
        guard let sender = sender as? NumberPadButton else {
            return
        }
        if !UIScreen.main.isCaptured {
            UIDevice.current.playInputClick()
        }
        target?.insertText(String(sender.number))
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        UIDevice.current.playInputDelete()
        target?.deleteBackward()
    }
    
    private func prepare() {
        loadXib()
        backgroundColor = R.color.keyboard_background_14()
        contentViewBottomConstraint.constant = contentBottomMargin + bottomSafeAreaInset
        self.bounds = CGRect(x: 0,
                             y: 0,
                             width: UIScreen.main.bounds.width,
                             height: contentHeight + bottomSafeAreaInset)
        layoutIfNeeded()
    }
    
}

extension NumberPadView: UIInputViewAudioFeedback {
    
    var enableInputClicksWhenVisible: Bool {
        return true
    }
    
}
