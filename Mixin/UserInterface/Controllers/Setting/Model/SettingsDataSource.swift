import UIKit

class SettingsDataSource: NSObject {
    
    // This variable must be set before tableView is set
    // Or the delegate forwarding will be unavailable
    weak var tableViewDelegate: UITableViewDelegate?
    
    weak var tableView: UITableView? {
        didSet {
            guard let tableView = tableView else {
                return
            }
            tableView.register(R.nib.settingCell)
            tableView.register(SettingsFooterView.self,
                               forHeaderFooterViewReuseIdentifier: footerReuseId)
            tableView.dataSource = self
            tableView.delegate = self
        }
    }
    
    private let footerReuseId = "footer"
    
    private(set) var sections: [SettingsSection]
    
    private var indexPaths = [SettingsRow: IndexPath]()
    
    init(sections: [SettingsSection]) {
        self.sections = sections
        super.init()
        var indexPaths = [SettingsRow: IndexPath](minimumCapacity: sections.count)
        for (sectionIndex, section) in sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                indexPaths[row] = indexPath
                row.observer = self
            }
        }
        self.indexPaths = indexPaths
    }
    
    override func responds(to aSelector: Selector!) -> Bool {
        let superResponds = super.responds(to: aSelector)
        let forwardeeResponds = tableViewDelegate?.responds(to: aSelector) ?? false
        return superResponds || forwardeeResponds
    }
    
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let delegate = tableViewDelegate, delegate.responds(to: aSelector) {
            return delegate
        } else {
            return super.forwardingTarget(for: aSelector)
        }
    }
    
    func row(at indexPath: IndexPath) -> SettingsRow {
        sections[indexPath.section].rows[indexPath.row]
    }
    
    func reloadRow(at indexPath: IndexPath, with row: SettingsRow, animation: UITableView.RowAnimation) {
        sections[indexPath.section].rows[indexPath.row] = row
        tableView?.reloadRows(at: [indexPath], with: animation)
    }
    
}

extension SettingsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.render(row: row)
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
}

extension SettingsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        64
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SettingsFooterView
        view.text = sections[section].footer
        return view
    }
    
}

extension SettingsDataSource: SettingsRowObserver {
    
    func settingsRow(_ row: SettingsRow, subtitleDidChangeTo newValue: String?) {
        guard let indexPath = indexPaths[row] else {
            return
        }
        guard let cell = tableView?.cellForRow(at: indexPath) as? SettingCell else {
            return
        }
        cell.subtitleLabel.text = newValue
    }
    
}
