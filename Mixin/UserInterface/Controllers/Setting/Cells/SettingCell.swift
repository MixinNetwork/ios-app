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
        accessorySwitchIfLoaded = accessorySwitch
        return accessorySwitch
    }()
    
    private(set) var accessoryImageViewIfLoaded: UIImageView?
    private(set) var accessorySwitchIfLoaded: UISwitch?
    
    func render(row: SettingsRow) {
        if let icon = row.icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
        titleLabel.text = row.title
        subtitleLabel.text = row.subtitle
        switch row.accessory {
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
            accessorySwitch.isOn = isOn
        }
    }
    
}
