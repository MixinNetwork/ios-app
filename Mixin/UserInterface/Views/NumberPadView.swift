import UIKit

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
        if #available(iOS 11.0, *) {
            var bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
            if bottom > 0 {
                bottom += 41
            }
            return bottom
        } else {
            return 0
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

    @IBAction func inputAction(_ sender: Any) {
        guard let sender = sender as? NumberPadButton else {
            return
        }
        target?.insertText(String(sender.number))
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        target?.deleteBackward()
    }
    
    private func prepare() {
        loadXib()
        var bounds = UIScreen.main.bounds
        bounds.size.height = contentHeight + bottomSafeAreaInset
        contentViewBottomConstraint.constant = contentBottomMargin + bottomSafeAreaInset
        self.bounds = bounds
        layoutIfNeeded()
    }
    
}
