import UIKit
import DeviceGuru

class NumberPadView: UIView, XibDesignable {

    @IBOutlet weak var contentViewBottomConstraint: NSLayoutConstraint!
    
    weak var target: UIKeyInput?
    
    private let contentHeight: CGFloat = 226
    private let bottomSafeAreaInset: CGFloat = 34
    private let contentBottomMargin: CGFloat = 2
    
    private static let needsLayoutForIPhoneX: Bool = {
        let hardware = DeviceGuru().hardware()
        return hardware == .iphoneX
            || hardware == .simulator && abs(UIScreen.main.bounds.height - 812) < 0.1
    }()
    
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
        if NumberPadView.needsLayoutForIPhoneX {
            bounds.size.height = contentHeight + bottomSafeAreaInset
            contentViewBottomConstraint.constant = contentBottomMargin + bottomSafeAreaInset
        } else {
            bounds.size.height = contentHeight
            contentViewBottomConstraint.constant = contentBottomMargin
        }
        self.bounds = bounds
        layoutIfNeeded()
    }
    
}
