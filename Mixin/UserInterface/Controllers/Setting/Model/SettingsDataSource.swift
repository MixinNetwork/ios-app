import UIKit

class SettingsDataSource: NSObject {
    
    private enum ReuseId {
        static let header = "header"
        static let footer = "footer"
    }
    
    // This variable must be set before tableView is set
    // Or the delegate forwarding will be unavailable
    weak var tableViewDelegate: UITableViewDelegate?
    
    weak var tableView: UITableView? {
        didSet {
            guard let tableView = tableView else {
                return
            }
            tableView.register(R.nib.settingCell)
            tableView.register(SettingsHeaderView.self,
                               forHeaderFooterViewReuseIdentifier: ReuseId.header)
            tableView.register(SettingsFooterView.self,
                               forHeaderFooterViewReuseIdentifier: ReuseId.footer)
            tableView.dataSource = self
            tableView.delegate = self
        }
    }
    
    private(set) var sections: [SettingsSection]
    
    private var indexPaths = [SettingsRow: IndexPath]()
    private var cachedHeaderSizes = [Int: CGSize]()
    private var cachedFooterSizes = [Int: CGSize]()
    
    init(sections: [SettingsSection]) {
        self.sections = sections
        super.init()
        reloadIndexPaths()
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateSectionFooter(_:)),
                           name: SettingsSection.footerDidChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateTitle(_:)),
                           name: SettingsRow.titleDidChangeNotification,
                           object: nil)
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
    
    func replaceSection(at location: Int, with section: SettingsSection, animation: UITableView.RowAnimation) {
        sections[location] = section
        tableView?.reloadSections(IndexSet(integer: location), with: animation)
        reloadIndexPaths()
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
    
    @objc func updateSectionFooter(_ notification: Notification) {
        guard let section = notification.object as? SettingsSection else {
            return
        }
        guard let index = sections.firstIndex(of: section) else {
            return
        }
        guard let view = tableView?.footerView(forSection: index) as? SettingsFooterView else {
            return
        }
        view.text = section.footer
    }
    
    @objc func updateTitle(_ notification: Notification) {
        guard let row = notification.object as? SettingsRow else {
            return
        }
        guard let indexPath = indexPaths[row] else {
            return
        }
        guard let cell = tableView?.cellForRow(at: indexPath) as? SettingCell else {
            return
        }
        cell.titleLabel.text = row.title
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
        
        if #available(iOS 13.0, *) {
            // No need for masking
        } else {
            let lastRowOfTheSection = sections[indexPath.section].rows.count - 1
            let roundTop = indexPath.row == 0
            let roundBottom = indexPath.row == lastRowOfTheSection
            var maskedCorners: CACornerMask = []
            if roundTop {
                maskedCorners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner])
            }
            if roundBottom {
                maskedCorners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
            }
            cell.layer.maskedCorners = maskedCorners
            cell.layer.cornerRadius = (roundTop || roundBottom) ? 10 : 0
        }
        
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
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let size = cachedHeaderSizes[section], size.width == tableView.bounds.width {
            return size.height
        } else {
            if let header = sections[section].header, !header.isEmpty {
                let layoutWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 375
                let labelLayoutSize = CGSize(width: layoutWidth - SettingsHeaderView.labelInset.horizontal,
                                             height: UIView.layoutFittingExpandedSize.height)
                let attributedText = NSAttributedString(string: header, attributes: SettingsHeaderView.attributes)
                let labelSize = attributedText.boundingRect(with: labelLayoutSize, options: [], context: nil)
                let height = SettingsHeaderView.labelInset.vertical + labelSize.height
                let size = CGSize(width: layoutWidth, height: ceil(height))
                cachedHeaderSizes[section] = size
                return size.height
            } else {
                if section == 0 {
                    return 10
                } else {
                    return 5
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if let size = cachedFooterSizes[section], size.width == tableView.bounds.width {
            return size.height
        } else {
            if let footer = sections[section].footer, !footer.isEmpty {
                let layoutWidth = tableView.bounds.width > 0 ? tableView.bounds.width : 375
                let labelLayoutSize = CGSize(width: layoutWidth - SettingsFooterView.labelInset.horizontal,
                                             height: UIView.layoutFittingExpandedSize.height)
                let attributedText = NSAttributedString(string: footer, attributes: SettingsFooterView.attributes)
                let labelSize = attributedText.boundingRect(with: labelLayoutSize, options: [], context: nil)
                let height = SettingsFooterView.labelInset.vertical + labelSize.height
                let size = CGSize(width: layoutWidth, height: ceil(height))
                cachedHeaderSizes[section] = size
                return size.height
            } else {
                if section == sections.count - 1 {
                    return 0
                } else {
                    return 5
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! SettingsHeaderView
        view.text = sections[section].header
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer) as! SettingsFooterView
        view.text = sections[section].footer
        return view
    }
    
}
