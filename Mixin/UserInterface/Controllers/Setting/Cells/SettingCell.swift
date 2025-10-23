import UIKit
import SDWebImage

final class SettingCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private(set) lazy var iconImageView: UIImageView = {
        let view = SDAnimatedImageView()
        view.contentMode = .center
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.tintColor = R.color.icon_tint()
        view.snp.makeConstraints { (make) in
            make.width.equalTo(24)
            make.height.equalTo(24).priority(.almostRequired)
        }
        view.shouldCustomLoopCount = true
        view.animationRepeatCount = 1
        iconImageViewIfLoaded = view
        return view
    }()
    
    private(set) lazy var subtitleImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.snp.makeConstraints { (make) in
            make.width.height.equalTo(18).priority(.almostRequired)
        }
        subtitleImageViewIfLoaded = view
        return view
    }()
    
    private(set) lazy var accessoryImageView: UIImageView = {
        let view = UIImageView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessoryImageViewIfLoaded = view
        return view
    }()
    
    private(set) lazy var accessorySwitch: UISwitch = {
        let accessorySwitch = UISwitch()
        accessorySwitch.setContentHuggingPriority(.required, for: .horizontal)
        accessorySwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessorySwitch.addTarget(self, action: #selector(switchAction(_:)), for: .valueChanged)
        accessorySwitch.onTintColor = .theme
        accessorySwitchIfLoaded = accessorySwitch
        return accessorySwitch
    }()
    
    private(set) lazy var accessoryBusyIndicator: ActivityIndicatorView = {
        let indicator = ActivityIndicatorView()
        indicator.tintColor = R.color.text_tertiary()!
        indicator.setContentHuggingPriority(.required, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessoryBusyIndicatorIfLoaded = indicator
        return indicator
    }()
    
    private(set) var iconImageViewIfLoaded: UIImageView?
    private(set) var subtitleImageViewIfLoaded: UIImageView?
    private(set) var accessoryImageViewIfLoaded: UIImageView?
    private(set) var accessorySwitchIfLoaded: UISwitch?
    private(set) var accessoryBusyIndicatorIfLoaded: ActivityIndicatorView?
    
    private var button: MenuTriggerButton?
    
    var row: SettingsRow? {
        didSet {
            guard let row = row else {
                return
            }
            if let icon = row.icon {
                iconImageView.image = icon
                if iconImageView.superview == nil {
                    contentStackView.insertArrangedSubview(iconImageView, at: 0)
                }
            } else {
                iconImageViewIfLoaded?.removeFromSuperview()
            }
            titleLabel.text = row.title
            titleLabel.textColor = switch row.titleStyle {
            case .normal:
                R.color.text()
            case .highlighted:
                R.color.theme()
            case .destructive:
                R.color.red()
            }
            setSubtitle(row.subtitle)
            updateAccessory(row.accessory, animated: false)
            if let menu = row.menu {
                let button: MenuTriggerButton
                if let b = self.button {
                    b.isHidden = false
                    button = b
                } else {
                    button = MenuTriggerButton()
                    button.showsMenuAsPrimaryAction = true
                    contentView.addSubview(button)
                    button.snp.makeEdgesEqualToSuperview()
                    self.button = button
                }
                button.menu = menu
            } else {
                button?.isHidden = true
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = R.color.background_input_selected()
            return view
        }()
    }
    
    func setSubtitle(_ subtitle: SettingsRow.Subtitle?) {
        switch subtitle {
        case .text(let text):
            subtitleLabel.text = text
            subtitleImageViewIfLoaded?.isHidden = true
        case .icon(let image):
            subtitleLabel.text = nil
            let imageView: UIImageView
            if let view = subtitleImageViewIfLoaded {
                imageView = view
            } else {
                imageView = subtitleImageView
                contentStackView.insertArrangedSubview(imageView, at: 3)
            }
            imageView.image = image
            imageView.isHidden = false
        case nil:
            subtitleLabel.text = nil
            subtitleImageViewIfLoaded?.isHidden = true
        }
    }
    
    func updateAccessory(_ accessory: SettingsRow.Accessory, animated: Bool) {
        if !animated {
            UIView.setAnimationsEnabled(false)
        }
        switch accessory {
        case .none:
            accessoryImageViewIfLoaded?.isHidden = true
            accessorySwitchIfLoaded?.isHidden = true
            accessoryBusyIndicatorIfLoaded?.stopAnimating()
        case .disclosure:
            accessoryBusyIndicatorIfLoaded?.stopAnimating()
            accessoryImageView.image = R.image.ic_accessory_disclosure()
            if accessoryImageView.superview == nil {
                contentStackView.addArrangedSubview(accessoryImageView)
            }
            accessoryImageView.isHidden = false
        case .checkmark:
            accessoryBusyIndicatorIfLoaded?.stopAnimating()
            accessoryImageView.image = R.image.setting.ic_checkmark()
            if accessoryImageView.superview == nil {
                contentStackView.addArrangedSubview(accessoryImageView)
            }
            accessoryImageView.isHidden = false
        case let .switch(isOn, isEnabled):
            if animated {
                UIView.setAnimationsEnabled(false)
            }
            accessoryBusyIndicatorIfLoaded?.stopAnimating()
            if accessorySwitch.superview == nil {
                contentStackView.addArrangedSubview(accessorySwitch)
            }
            accessorySwitch.isHidden = false
            if animated {
                UIView.setAnimationsEnabled(true)
            }
            accessorySwitch.isEnabled = isEnabled
            accessorySwitch.setOn(isOn, animated: animated)
        case .busy:
            accessoryImageViewIfLoaded?.isHidden = true
            if accessoryBusyIndicator.superview == nil {
                contentStackView.addArrangedSubview(accessoryBusyIndicator)
            }
            accessoryBusyIndicator.isHidden = false
            accessoryBusyIndicator.startAnimating()
        }
        UIView.setAnimationsEnabled(true)
    }
    
    @objc func switchAction(_ sender: UISwitch) {
        guard let row = row, case .switch = row.accessory else {
            return
        }
        row.accessory = .switch(isOn: sender.isOn)
    }
    
}
