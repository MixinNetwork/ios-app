import UIKit

class BouncingButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted && !oldValue {
                UIView.animate(withDuration: 0.1, animations: {
                    self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                })
            } else if !isHighlighted && oldValue {
                UIView.animate(withDuration: 0.1, animations: {
                    self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }, completion: { (finished) in
                    UIView.animate(withDuration: 0.1, animations: {
                        self.transform = .identity
                    })
                })
            }
        }
    }

}

