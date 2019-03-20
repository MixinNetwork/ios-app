import UIKit

class CheckmarkView: UIView {
    
    enum Status {
        case selected
        case unselected
        case forceSelected
        case hidden
    }
    
    let imageView = UIImageView()
    
    var status = Status.unselected {
        didSet {
            switch status {
            case .selected:
                imageView.image = UIImage(named: "ic_selected")
            case .unselected:
                imageView.image = UIImage(named: "ic_unselected")
            case .forceSelected:
                imageView.image = UIImage(named: "ic_force_selected")
            case .hidden:
                imageView.image = nil
            }
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
    
    private func prepare() {
        imageView.contentMode = .center
        addSubview(imageView)
    }
    
}
