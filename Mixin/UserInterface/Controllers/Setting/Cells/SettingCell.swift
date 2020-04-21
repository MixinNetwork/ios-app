import UIKit

final class SettingCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
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
    
    private(set) var accessoryImageViewIfLoaded: UIImageView?
    private(set) var accessorySwitchIfLoaded: UISwitch?
    
    var row: SettingsRow? {
        didSet {
            guard let row = row else {
                return
            }
            if let icon = row.icon {
                iconImageView.image = icon
                iconImageView.isHidden = false
            } else {
                iconImageView.isHidden = true
            }
            titleLabel.text = row.title
            subtitleLabel.text = row.subtitle
            updateAccessory(row.accessory, animated: false)
        }
    }
    
    func updateAccessory(_ accessory: SettingsRow.Accessory, animated: Bool) {
        switch accessory {
        case .none:
            accessoryImageViewIfLoaded?.isHidden = true
            accessorySwitchIfLoaded?.isHidden = true
        case .disclosure:
            accessoryImageView.image = R.image.ic_accessory_disclosure()
            if accessoryImageView.superview == nil {
                contentStackView.addArrangedSubview(accessoryImageView)
            }
        case .checkmark(let isChecked):
            accessoryImageView.image = isChecked ? R.image.ic_checkmark() : nil
            if accessoryImageView.superview == nil {
                contentStackView.addArrangedSubview(accessoryImageView)
            }
        case .switch(let isOn):
            if accessoryImageView.superview == nil {
                contentStackView.addArrangedSubview(accessorySwitch)
            }
            accessorySwitch.setOn(isOn, animated: animated)
        }
    }
    
    @objc func switchAction(_ sender: UISwitch) {
        guard let row = row, case .switch = row.accessory else {
            return
        }
        row.accessory = .switch(sender.isOn)
    }
    
}
