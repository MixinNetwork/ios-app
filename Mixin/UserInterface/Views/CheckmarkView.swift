import UIKit

class CheckmarkView: UIView {
    
    enum Status {
        case selected
        case deselected
        case nonSelectable
        case hidden
    }
    
    let imageView = UIImageView()
    
    var usesHighContrastDeselectedIcon = false
    
    var status = Status.hidden {
        didSet {
            switch status {
            case .selected:
                imageView.image = R.image.ic_selected()
            case .deselected:
                imageView.image = usesHighContrastDeselectedIcon
                    ? R.image.ic_deselected_high_contrast()
                    : R.image.ic_deselected()
            case .nonSelectable:
                imageView.image = R.image.ic_force_selected()
            case .hidden:
                imageView.image = nil
            }
            imageView.sizeToFit()
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
    
    override var debugDescription: String {
        var desc = super.debugDescription
        if let index = desc.lastIndex(of: ">") {
            desc.insert(contentsOf: "; status: \(status)", at: index)
        }
        return desc
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    private func prepare() {
        imageView.contentMode = .center
        addSubview(imageView)
    }
    
}
