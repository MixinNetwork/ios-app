import UIKit

class CircleEditingButton: UIButton {
    
    enum Style {
        case none
        case delete
        case insert
    }
    
    override var intrinsicContentSize: CGSize {
        contentSize
    }
    
    var style: Style = .none {
        didSet {
            setImage(style: style)
        }
    }
    
    private let contentSize = CGSize(width: 36, height: 80)
    
    private func setImage(style: Style) {
        let image: UIImage?
        switch style {
        case .none:
            image = nil
        case .delete:
            image = R.image.ic_circle_edit_delete()!
        case .insert:
            image = R.image.ic_circle_edit_insert()!
        }
        setImage(image, for: .normal)
    }
    
}
