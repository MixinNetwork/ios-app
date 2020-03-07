import UIKit

class ImageMessageCell: DetailInfoMessageCell {
    
    let maskingView = UIView()
    let trailingInfoBackgroundView = TrailingInfoBackgroundView()
    
    lazy var selectedOverlapView: UIView = {
        let view = SelectedOverlapView()
        view.alpha = 0
        contentView.addSubview(view)
        return view
    }()
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapView.alpha = highlight ? 1 : 0
        }
        if viewModel?.quotedMessageViewModel != nil {
            super.updateAppearance(highlight: highlight, animated: animated)
        }
    }
    
}

extension ImageMessageCell {
    
    class SelectedOverlapView: UIView {
        
        override var backgroundColor: UIColor? {
            set { }
            get { super.backgroundColor }
        }
        
        convenience init() {
            self.init(frame: .zero)
            super.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        }
        
    }
    
}
