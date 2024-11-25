import UIKit

final class ChangeMobileNumberViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.change_mobile_number(), accessory: .disclosure)
        ]),
    ])
    
    private let phoneNumber: String
    private let tableHeaderView = R.nib.imageTextTableHeaderView(withOwner: nil)!
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init(phoneNumber: String) {
        self.phoneNumber = phoneNumber
        super.init(nibName: nil, bundle: nil)
    }
    
    static func contained(phoneNumber: String) -> ContainerViewController {
        let viewController = ChangeMobileNumberViewController(phoneNumber: phoneNumber)
        let container = ContainerViewController.instance(viewController: viewController, title: "")
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.mobile_number()
        tableHeaderView.textView.attributedText = {
            let moreInfo = R.string.localizable.more_information()
            let string = R.string.localizable.change_phone_desc(phoneNumber, moreInfo)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text()!,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    style.lineHeightMultiple = 1.5
                    return style
                }(),
            ]
            let attributedString = NSMutableAttributedString(string: string, attributes: attributes)
            let range = (string as NSString).range(of: moreInfo, options: .backwards)
            attributedString.addAttribute(.link, value: URL.tip, range: range)
            attributedString.addAttribute(.foregroundColor, value: R.color.theme()!, range: range)
            return attributedString
        }()
        tableView.tableHeaderView = tableHeaderView
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableHeaderView.sizeToFit(tableView: tableView)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            tableHeaderView.sizeToFit(tableView: tableView)
        }
    }
    
}

extension ChangeMobileNumberViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let introduction = MobileNumberIntroductionViewController.contained(action: .change)
        navigationController?.pushViewController(introduction, animated: true)
    }
    
}
