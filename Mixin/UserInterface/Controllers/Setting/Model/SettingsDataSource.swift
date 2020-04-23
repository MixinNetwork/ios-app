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
        reloadIndexPaths()
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateSubtitle(_:)),
                           name: SettingsRow.subtitleDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateAccessory(_:)),
                           name: SettingsRow.accessoryDidChangeNotification,
                           object: nil)
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
    
    func insertSection(_ section: SettingsSection, at location: Int, animation: UITableView.RowAnimation) {
        sections.insert(section, at: location)
        tableView?.insertSections(IndexSet(integer: location), with: animation)
        reloadIndexPaths()
    }
    
    func reloadSections(_ sections: [SettingsSection]) {
        self.sections = sections
        tableView?.reloadData()
        reloadIndexPaths()
    }
    
    func appendRows(_ rows: [SettingsRow], into section: Int, animation: UITableView.RowAnimation) {
        let start = sections[section].rows.count
        let end = sections[section].rows.count + rows.count
        let indexPaths = (start..<end).map { (row) -> IndexPath in
            IndexPath(row: row, section: section)
        }
        sections[section].rows.append(contentsOf: rows)
        tableView?.insertRows(at: indexPaths, with: animation)
        reloadIndexPaths()
    }
    
    func deleteRow(at indexPath: IndexPath, animation: UITableView.RowAnimation) {
        sections[indexPath.section].rows.remove(at: indexPath.row)
        tableView?.deleteRows(at: [indexPath], with: animation)
        reloadIndexPaths()
    }
    
    func reloadRow(_ row: SettingsRow, at indexPath: IndexPath, animation: UITableView.RowAnimation) {
        sections[indexPath.section].rows[indexPath.row] = row
        tableView?.reloadRows(at: [indexPath], with: animation)
        reloadIndexPaths()
    }
    
    @objc func updateSubtitle(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard let indexPath = indexPaths[row] else {
            return
        }
        guard let cell = tableView?.cellForRow(at: indexPath) as? SettingCell else {
            return
        }
        cell.subtitleLabel.text = row.subtitle
    }
    
    @objc func updateAccessory(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard let indexPath = indexPaths[row] else {
            return
        }
        guard let cell = tableView?.cellForRow(at: indexPath) as? SettingCell else {
            return
        }
        cell.updateAccessory(row.accessory, animated: true)
    }
    
    private func reloadIndexPaths() {
        var indexPaths = [SettingsRow: IndexPath](minimumCapacity: sections.count)
        for (sectionIndex, section) in sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                indexPaths[row] = indexPath
            }
        }
        self.indexPaths = indexPaths
    }
    
}

extension SettingsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        let row = sections[indexPath.section].rows[indexPath.row]
        cell.row = row
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SettingsFooterView
        view.text = sections[section].header
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SettingsFooterView
        view.text = sections[section].footer
        return view
    }
    
}
