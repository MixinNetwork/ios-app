import UIKit

class DeviceTransferSettingViewController: SettingsTableViewController {
    
    let tableHeaderView = R.nib.deviceTransferActionTableHeaderView(withOwner: nil)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = tableHeaderView
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.width != tableHeaderView.frame.width {
            updateTableHeaderView()
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateTableHeaderView()
        }
    }
    
    private func updateTableHeaderView() {
        let sizeToFit = CGSize(width: view.bounds.width, height: UIView.layoutFittingExpandedSize.height)
        let headerHeight = tableHeaderView.sizeThatFits(sizeToFit).height
        tableHeaderView.frame.size = CGSize(width: view.bounds.width, height: headerHeight)
        tableView.tableHeaderView = tableHeaderView
    }
    
}
