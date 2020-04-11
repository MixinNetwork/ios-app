import UIKit

class RoundedInsetLabel: InsetLabel {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
}
