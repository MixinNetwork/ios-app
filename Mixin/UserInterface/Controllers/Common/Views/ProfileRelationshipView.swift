import UIKit

final class ProfileRelationshipView: UIView {
    
    enum Style {
        case none
        case addContact
        case addBot
        case unblock
        case joinGroup
    }
    
    let button = UIButton(type: .system)
    
    var isBusy = false {
        didSet{
            update(isBusy: isBusy)
        }
    }
    
    var style = Style.none {
        didSet {
            update(style: style)
        }
    }
    
    private var busyIndicator: ActivityIndicatorView?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    convenience init() {
        let frame = CGRect(x: 0, y: 0, width: 414, height: 40)
        self.init(frame: frame)
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 320, height: 40)
    }
    
    private func update(style: Style) {
        UIView.performWithoutAnimation {
            switch style {
            case .none:
                button.setImage(nil, for: .normal)
                button.setTitle(nil, for: .normal)
            case .addContact:
                button.setImage(R.image.ic_profile_add(), for: .normal)
                button.setTitle(R.string.localizable.profile_add_contact(), for: .normal)
            case .addBot:
                button.setImage(R.image.ic_profile_add(), for: .normal)
                button.setTitle(R.string.localizable.profile_add_bot(), for: .normal)
            case .unblock:
                button.setImage(R.image.ic_profile_unblock(), for: .normal)
                button.setTitle(R.string.localizable.profile_unblock(), for: .normal)
            case .joinGroup:
                button.setImage(R.image.ic_profile_add(), for: .normal)
                button.setTitle(R.string.localizable.group_button_title_join(), for: .normal)
            }
            button.layoutIfNeeded()
        }
    }
    
    private func update(isBusy: Bool) {
        button.isHidden = isBusy
        if isBusy {
            if busyIndicator == nil {
                let frame = CGRect(origin: center, size: .zero).insetBy(dx: -10, dy: -10)
                busyIndicator = ActivityIndicatorView(frame: frame)
                busyIndicator!.tintColor = .accessoryText
            }
            if let indicator = busyIndicator {
                if indicator.superview == nil {
                    addSubview(indicator)
                    indicator.snp.makeConstraints { (make) in
                        make.center.equalToSuperview()
                    }
                }
                indicator.startAnimating()
            }
        } else {
            if let indicator = busyIndicator {
                indicator.stopAnimating()
                indicator.removeFromSuperview()
            }
            busyIndicator = nil
        }
    }
    
    private func prepare() {
        button.backgroundColor = .inputBackground
        button.layer.cornerRadius = 14
        button.clipsToBounds = true

        button.setTitleColor(.theme, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 19, bottom: 0, right: 15)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 0)
        addSubview(button)
        button.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.height.equalTo(28)
        }
    }
    
}
