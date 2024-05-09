import UIKit
import MixinServices

class Web3HeaderView: UIView {
    
    @IBOutlet weak var actionStackView: UIStackView!
    
    weak var sendButton: UIButton!
    weak var receiveButton: UIButton!
    weak var browseButton: UIButton!
    weak var moreButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sendButton = addAction(title: R.string.localizable.caption_send(),
                               icon: R.image.web3_action_send()!)
        receiveButton = addAction(title: R.string.localizable.receive(),
                                  icon: R.image.web3_action_receive()!)
    }
    
    func addTarget(_ target: Any, send: Selector, receive: Selector) {
        sendButton.removeTarget(nil, action: nil, for: .allEvents)
        sendButton.addTarget(target, action: send, for: .touchUpInside)
        
        receiveButton.removeTarget(nil, action: nil, for: .allEvents)
        receiveButton.addTarget(target, action: receive, for: .touchUpInside)
    }
    
    func addAction(title: String, icon: UIImage) -> UIButton {
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
        
        actionStackView.addArrangedSubview(wrapper)
        return button
    }
    
}
