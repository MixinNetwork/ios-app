import UIKit

class ProfileMenuItemView: UIView, XibDesignable {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var button: HighlightableButton!
    @IBOutlet weak var label: ProfileMenuItemLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    weak var target: NSObject?
    
    var nibName: String {
        return String(describing: type(of: self))
    }
    
    var item: ProfileMenuItem? {
        didSet {
            guard let item = item else {
                return
            }
            label.text = item.title
            label.ibOverridingTextColor = item.style.contains(.destructive) ? .mixinRed : .text
            subtitleLabel.text = item.subtitle
        }
    }
    
    var contentEdgeInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 17, bottom: 0, right: 17)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    convenience init() {
        let frame = CGRect(x: 0, y: 0, width: 414, height: 64)
        self.init(frame: frame)
    }
    
    func prepare() {
        loadXib()
    }
    
    @IBAction func selectAction(_ sender: Any) {
        guard let target = target, let item = item else {
            return
        }
        target.perform(item.action)
    }
    
}
