import UIKit

class SearchCancelButton: UIButton {
    
    convenience init() {
        self.init(type: .system)
        titleLabel?.font = .systemFont(ofSize: 16)
        setTitleColor(.highlightedText, for: .normal)
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        setTitle(R.string.localizable.dialog_button_cancel(), for: .normal)
        sizeToFit()
        frame.size.height = 44
    }
    
}
