import UIKit

final class SettingCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private(set) lazy var iconImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.tintColor = R.color.icon_tint()
        view.snp.makeConstraints { (make) in
            make.width.height.equalTo(24).priority(.almostRequired)
        }
        iconImageViewIfLoaded = view
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
        indicator.tintColor = .accessoryText
        indicator.setContentHuggingPriority(.required, for: .horizontal)
        indicator.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessoryBusyIndicatorIfLoaded = indicator
        return indicator
    }()
    
    private(set) var iconImageViewIfLoaded: UIImageView?
    private(set) var accessoryImageViewIfLoaded: UIImageView?
    private(set) var accessorySwitchIfLoaded: UISwitch?
    private(set) var accessoryBusyIndicatorIfLoaded: ActivityIndicatorView?
    
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
            titleLabel.textColor = {
                switch row.titleStyle {
                case .normal:
                    return .text
                case .highlighted:
                    return .theme
                case .destructive:
                    return .walletRed
                }
            }()
            subtitleLabel.text = row.subtitle
            updateAccessory(row.accessory, animated: false)
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
