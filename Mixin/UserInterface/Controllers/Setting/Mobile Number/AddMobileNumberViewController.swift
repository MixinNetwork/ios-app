import UIKit
import MixinServices

final class AddMobileNumberViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.add_mobile_number(), accessory: .disclosure)
        ]),
    ])
    
    private let tableHeaderView = R.nib.imageTextTableHeaderView(withOwner: nil)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.mobile_number()
        tableHeaderView.textViewTopConstraint.constant = 36
        tableHeaderView.textView.attributedText = .linkedMoreInfo(
            content: R.string.localizable.add_phone_desc,
            font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
            color: R.color.text()!,
            moreInfoURL: .tip
        )
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

extension AddMobileNumberViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let introduction = MobileNumberIntroductionViewController(action: .add)
        navigationController?.pushViewController(introduction, animated: true)
    }
    
}
