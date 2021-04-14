import UIKit

class MyFavoriteAppProfileMenuItemView: UIView, XibDesignable {
    
    @IBOutlet weak var button: HighlightableButton!
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
    
    private func prepare() {
        loadXib()
        avatarStackView.avatarBackgroundColor = .inputBackground
    }
    
}
