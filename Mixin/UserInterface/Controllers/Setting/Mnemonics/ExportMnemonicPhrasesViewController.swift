import UIKit
import MixinServices

final class ExportMnemonicPhrasesViewController: SettingsTableViewController {
    
    private let tableHeaderView = R.nib.imageTextTableHeaderView(withOwner: nil)!
    private let dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.backup_mnemonic_phrase(), accessory: .disclosure)
        ]),
    ])
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    class func contained() -> UIViewController {
        let vc = ExportMnemonicPhrasesViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.mnemonic_phrase())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.imageView.image = R.image.mnemonic_phrase()
        tableHeaderView.textViewTopConstraint.constant = 36
        tableHeaderView.textView.attributedText = .linkedMoreInfo(
            content: R.string.localizable.mnemonic_phrase_instruction,
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

extension ExportMnemonicPhrasesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch TIP.status {
        case .ready, .needsMigrate:
            let introduction = ExportMnemonicPhrasesIntroductionViewController.contained()
            navigationController?.pushViewController(replacingCurrent: introduction, animated: true)
        case .needsInitialize:
            let tip = TIPNavigationViewController(intent: .create, destination: nil)
            navigationController?.present(tip, animated: true)
        case .unknown:
            break
        }
    }
    
}