import UIKit
import MixinServices

final class NumberPadView: UIView, XibDesignable {

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
        if windowSafeAreaInsets.bottom > 0 {
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

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateBottomInset()
        invalidateIntrinsicContentSize()
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
    
    private func updateBottomInset() {
        contentViewBottomConstraint.constant = contentBottomMargin + bottomSafeAreaInset
        self.bounds = CGRect(x: 0,
                             y: 0,
                             width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width,
                             height: contentHeight + bottomSafeAreaInset)
        layoutIfNeeded()
    }

    private func prepare() {
        loadXib()
        backgroundColor = R.color.keyboard_background_14()
        updateBottomInset()
    }
    
}

extension NumberPadView: UIInputViewAudioFeedback {
    
    var enableInputClicksWhenVisible: Bool {
        return true
    }
    
}
