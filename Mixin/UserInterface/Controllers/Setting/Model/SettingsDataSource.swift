import UIKit

class SettingsDataSource: NSObject {
    
    weak var tableView: UITableView? {
        didSet {
            guard let tableView = tableView else {
                return
            }
            tableView.register(R.nib.settingCell)
            tableView.delegate = self
        }
    }
    
    weak var tableViewDelegate: UITableViewDelegate?
    
    let sections: [SettingsSection]
    
    init(sections: [SettingsSection]) {
        self.sections = sections
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
    
}
