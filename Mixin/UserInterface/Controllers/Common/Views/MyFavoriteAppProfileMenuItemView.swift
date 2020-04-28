import UIKit

class MyFavoriteAppProfileMenuItemView: UIView, XibDesignable {
    
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var avatarStackView: UserAvatarStackView!
    
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateButtonBackground()
    }
    
    private func prepare() {
        loadXib()
        updateButtonBackground()
        avatarStackView.avatarBackgroundColor = .inputBackground
    }
    
    private func updateButtonBackground() {
        button.setBackgroundImage(UIColor.inputBackground.image, for: .normal)
        button.setBackgroundImage(R.color.background_input_selected()!.image, for: .highlighted)
    }
    
}
