import UIKit
import AVKit

class NumberPadView: UIView, XibDesignable {

    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    
    weak var target: UIKeyInput?
    
    private let contentBottomMargin: CGFloat = 2
    
    private var contentHeight: CGFloat {
        let height: CGFloat = 226
        if bottomSafeAreaInset > 0 {
            return height - 10
        } else {
            return height
        }
    }
    
    private var bottomSafeAreaInset: CGFloat {
        var bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
        if bottom > 0 {
            bottom += 41
        }
        return bottom
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
        if #available(iOS 14.0, *) {
            backgroundColor = R.color.keyboard_background_14()
        } else {
            backgroundColor = R.color.keyboard_background_13()
        }
        var bounds = UIScreen.main.bounds
        bounds.size.height = contentHeight + bottomSafeAreaInset
        contentViewBottomConstraint.constant = contentBottomMargin + bottomSafeAreaInset
        self.bounds = bounds
        layoutIfNeeded()
    }
    
}

extension NumberPadView: UIInputViewAudioFeedback {
    
    var enableInputClicksWhenVisible: Bool {
        return true
    }
    
}
