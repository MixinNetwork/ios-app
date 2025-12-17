import UIKit
import MixinServices

class WalletIdentifyingAuthenticationPreviewViewController: AuthenticationPreviewViewController {
    
    private let wallet: Wallet
    
    private weak var walletIdentifyingView: UIView!
    private weak var walletIdentifyingContentView: UIStackView!
    private weak var walletNameLabel: UILabel!
    
    init(wallet: Wallet, warnings: [String]) {
        self.wallet = wallet
        super.init(warnings: warnings)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        walletIdentifyingContentView.spacing = 4
        walletIdentifyingContentView.alignment = .center
        walletIdentifyingContentView.distribution = .fill
        walletIdentifyingContentView.axis = .horizontal
        
        walletNameLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        walletNameLabel.textColor = .white
        walletNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        tableView.layer.cornerRadius = 10
        tableView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableView.layer.masksToBounds = true
        
        switch wallet {
        case .privacy:
            walletIdentifyingView.backgroundColor = R.color.privacy_wallet()
            walletNameLabel.text = R.string.localizable.privacy_wallet()
            let privacyShield = R.image.privacy_wallet()?.withRenderingMode(.alwaysTemplate)
            let privacyShieldView = UIImageView(image: privacyShield)
            privacyShieldView.tintColor = .white
            walletIdentifyingContentView.addArrangedSubview(privacyShieldView)
            privacyShieldView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            privacyShieldView.snp.makeConstraints { make in
                make.width.height.equalTo(22)
            }
        case .common(let wallet):
            walletIdentifyingView.backgroundColor = R.color.theme()
            walletNameLabel.text = wallet.name
        case .safe:
            assertionFailure("No auth preview for safe wallets")
            break
        }
    }
    
    override func loadTableView() {
        let walletIdentifyingView = UIView()
        view.addSubview(walletIdentifyingView)
        walletIdentifyingView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        self.walletIdentifyingView = walletIdentifyingView
        
        let walletIdentifyingContentView = UIStackView()
        walletIdentifyingView.addSubview(walletIdentifyingContentView)
        walletIdentifyingContentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(7)
            make.bottom.equalToSuperview().offset(-17)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        self.walletIdentifyingContentView = walletIdentifyingContentView
        
        let walletNameLabel = UILabel()
        walletIdentifyingContentView.addArrangedSubview(walletNameLabel)
        self.walletNameLabel = walletNameLabel
        
        tableView = UITableView(frame: view.bounds, style: tableViewStyle)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(walletIdentifyingView.snp.bottom).offset(-10)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
}
