import UIKit

class SelectedCellBackgroundView: UIView {
    
    convenience init() {
        self.init(frame: .zero)
        backgroundColor = .selectionBackground
    }
    
}
