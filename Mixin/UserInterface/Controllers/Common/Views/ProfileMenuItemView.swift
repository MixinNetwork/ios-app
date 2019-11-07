import UIKit

final class ProfileMenuItemView: UIView, XibDesignable {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var accessoryDisclosureImageView: UIImageView!
    
    weak var target: NSObject?
    
    var item: ProfileMenuItem? {
        didSet {
            guard let item = item else {
                return
            }
            label.text = item.title
            label.textColor = item.style.contains(.destructive) ? .mixinRed : .text
            subtitleLabel.text = item.subtitle
            accessoryDisclosureImageView.isHidden = !item.style.contains(.accessoryDisclosure)
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
    
    @IBAction func selectAction(_ sender: Any) {
        guard let target = target, let item = item else {
            return
        }
        target.perform(item.action)
    }
    
    private func prepare() {
        loadXib()
        button.setBackgroundImage(UIColor.tertiaryBackground.image, for: .normal)
        button.setBackgroundImage(UIColor.secondaryBackground.image, for: .highlighted)
    }
    
}
