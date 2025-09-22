import UIKit

final class AboutViewController: SettingsTableViewController {
    
    @IBOutlet weak var versionLabel: UILabel!
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.follow_us_on_x(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.follow_us_on_facebook(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.help_center(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.terms_of_service(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.privacy_policy(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.acknowledgements(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.version_update(), accessory: .disclosure)
        ])
    ])
    
    private let footerView = FooterView()
    
    private lazy var diagnoseRow = SettingsRow(title: R.string.localizable.diagnose(), accessory: .disclosure)
    
    private var isShowingDiagnoseRow = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.aboutTableHeaderView(withOwner: self)
        footerView.button.addTarget(self, action: #selector(revealOpenSource(_:)), for: .touchUpInside)
        footerView.sizeToFit(tableView: tableView)
        tableView.tableFooterView = footerView
        versionLabel.text = Bundle.main.fullVersion
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        #if DEBUG
        showDiagnoseRow(self)
        #endif
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        footerView.sizeToFit(tableView: tableView)
        tableView.tableFooterView = footerView
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            footerView.sizeToFit(tableView: tableView)
            tableView.tableFooterView = footerView
        }
    }
    
    @IBAction func showDiagnoseRow(_ sender: Any) {
        guard !isShowingDiagnoseRow else {
            return
        }
        dataSource.appendRows([diagnoseRow], into: 0, animation: .automatic)
        isShowingDiagnoseRow = true
    }
    
    @objc private func revealOpenSource(_ sender: Any) {
        UIApplication.shared.openURL(url: .openSource)
    }
    
}

extension AboutViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            UIApplication.shared.openURL(url: "https://x.com/intent/follow?screen_name=MixinMessenger")
        case 1:
            UIApplication.shared.openURL(url: "https://fb.com/MixinMessenger")
        case 2:
            UIApplication.shared.openURL(url: .support)
        case 3:
            UIApplication.shared.openURL(url: .terms)
        case 4:
            UIApplication.shared.openURL(url: .privacy)
        case 5:
            let acknow = AcknowledgementListViewController()
            navigationController?.pushViewController(acknow, animated: true)
        case 6:
            UIApplication.shared.open(.mixinMessenger, options: [:], completionHandler: nil)
        case 7:
            let diagnose = DiagnoseViewController()
            navigationController?.pushViewController(diagnose, animated: true)
        default:
            break
        }
    }
    
}

extension AboutViewController {
    
    private final class FooterView: UIView {
        
        let button = UIButton(type: .system)
        
        private let buttonVerticalMargin: CGFloat = 16
        
        private var lastLayoutWidth: CGFloat?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadSubviews()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadSubviews()
        }
        
        func sizeToFit(tableView: UITableView) {
            let width = tableView.bounds.width
            guard width != lastLayoutWidth else {
                return
            }
            let sizeToFit = CGSize(width: width, height: UIView.layoutFittingExpandedSize.height)
            let height = button.sizeThatFits(sizeToFit).height + buttonVerticalMargin * 2
            frame.size = CGSize(width: width, height: height)
            lastLayoutWidth = width
        }
        
        private func loadSubviews() {
            var configuration: UIButton.Configuration = .plain()
            configuration.buttonSize = .medium
            configuration.background = .clear()
            configuration.baseForegroundColor = R.color.text_tertiary()
            configuration.attributedTitle = {
                let paragraphSytle = NSMutableParagraphStyle()
                paragraphSytle.alignment = .center
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .footnote),
                    .paragraphStyle: paragraphSytle
                ]
                return AttributedString(
                    R.string.localizable.open_source(),
                    attributes: AttributeContainer(attributes)
                )
            }()
            button.configuration = configuration
            addSubview(button)
            button.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(buttonVerticalMargin)
                make.bottom.equalToSuperview().offset(-buttonVerticalMargin)
                make.centerX.equalToSuperview()
                make.leading.greaterThanOrEqualToSuperview()
                make.trailing.lessThanOrEqualToSuperview()
            }
        }
        
    }
    
}
