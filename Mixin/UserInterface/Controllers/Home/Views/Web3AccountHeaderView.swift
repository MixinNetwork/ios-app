import UIKit
import MixinServices

final class Web3AccountHeaderView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    @IBOutlet weak var actionsMarginWidthConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(20, after: amountStackView)
        symbolLabel.text = Currency.current.symbol
        amountLabel.font = .condensed(size: 40)
        amountLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        amountLabel.text = "0" + currentDecimalSeparator + "00"
        switch ScreenWidth.current {
        case .long:
            actionsMarginWidthConstraint.constant = 20
        case .medium, .short:
            actionsMarginWidthConstraint.constant = 0
        }
    }
    
    func setNetworkName(_ name: String) {
        accountNameLabel.text = R.string.localizable.web3_account_network(name)
    }
    
    func addAction(title: String, icon: UIImage, target: Any, action: Selector) {
        let wrapper = UIView()
        
        let backgroundImageView = UIImageView(image: R.image.explore.action_tray())
        wrapper.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        
        let label = UILabel()
        label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        label.textColor = R.color.text()
        label.textAlignment = .center
        label.text = title
        wrapper.addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(backgroundImageView.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        let button = UIButton(type: .system)
        button.contentMode = .center
        button.tintColor = R.color.icon_tint()
        button.setImage(icon, for: .normal)
        wrapper.addSubview(button)
        button.snp.makeConstraints { make in
            make.edges.equalTo(backgroundImageView)
        }
        button.addTarget(target, action: action, for: .touchUpInside)
        
        wrapper.snp.makeConstraints { make in
            make.width.equalTo(56)
        }
        actionStackView.addArrangedSubview(wrapper)
    }
    
}
