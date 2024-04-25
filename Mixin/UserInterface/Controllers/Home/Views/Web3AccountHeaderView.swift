import UIKit
import MixinServices

final class Web3AccountHeaderView: UIView {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var actionStackView: UIStackView!
    
    private(set) weak var sendButton: UIButton!
    private(set) weak var receiveButton: UIButton!
    private(set) weak var browseButton: UIButton!
    private(set) weak var moreButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.text = Currency.current.symbol
        amountLabel.font = .condensed(size: 40)
        amountLabel.contentInset = UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0)
        amountLabel.text = "0" + currentDecimalSeparator + "00"
        sendButton = addAction(title: R.string.localizable.caption_send(),
                               icon: R.image.web3_action_send()!)
        receiveButton = addAction(title: R.string.localizable.receive(),
                                  icon: R.image.web3_action_receive()!)
        browseButton = addAction(title: R.string.localizable.browser(),
                                 icon: R.image.web3_action_browser()!)
        moreButton = addAction(title: R.string.localizable.more(),
                               icon: R.image.web3_action_more()!)
    }
    
    func setNetworkName(_ name: String) {
        accountNameLabel.text = R.string.localizable.web3_account_network(name)
    }
    
    func addTarget(_ target: Any, send: Selector, receive: Selector, browse: Selector, more: Selector) {
        sendButton.removeTarget(nil, action: nil, for: .allEvents)
        sendButton.addTarget(target, action: send, for: .touchUpInside)
        
        receiveButton.removeTarget(nil, action: nil, for: .allEvents)
        receiveButton.addTarget(target, action: receive, for: .touchUpInside)
        
        browseButton.removeTarget(nil, action: nil, for: .allEvents)
        browseButton.addTarget(target, action: browse, for: .touchUpInside)
        
        moreButton.removeTarget(nil, action: nil, for: .allEvents)
        moreButton.addTarget(target, action: more, for: .touchUpInside)
    }
    
    private func addAction(title: String, icon: UIImage) -> UIButton {
        if #available(iOS 15.0, *) {
            var config: UIButton.Configuration = .plain()
            config.baseBackgroundColor = .clear
            config.background = {
                var config: UIBackgroundConfiguration = .clear()
                config.image = R.image.explore.action_tray()
                config.imageContentMode = .top
                return config
            }()
            config.imagePlacement = .top
            config.imagePadding = 25
            config.imageReservation = 24
            config.image = icon.withRenderingMode(.alwaysTemplate)
            config.attributedTitle = {
                let attributes = AttributeContainer([
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: R.color.text()!,
                ])
                return AttributedString(title, attributes: attributes)
            }()
            config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 0, bottom: 0, trailing: 0)
            let button = UIButton()
            button.tintColor = R.color.text()
            button.configuration = config
            button.configurationUpdateHandler = { button in
                let isNormalState = button.state.intersection([.disabled, .highlighted]).isEmpty
                if isNormalState {
                    button.alpha = 1
                } else {
                    switch button.traitCollection.userInterfaceStyle {
                    case .dark:
                        button.alpha = 0.45
                    case .unspecified, .light:
                        fallthrough
                    @unknown default:
                        button.alpha = 0.3
                    }
                }
            }
            actionStackView.addArrangedSubview(button)
            return button
        } else {
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
            
            wrapper.snp.makeConstraints { make in
                make.width.equalTo(56)
            }
            actionStackView.addArrangedSubview(wrapper)
            
            return button
        }
    }
    
}
