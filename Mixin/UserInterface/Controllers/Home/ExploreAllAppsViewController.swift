import UIKit
import MixinServices

final class ExploreAllAppsViewController: UITableViewController {
    
    private let headerReuseID = "header"
    
    private(set) var allUsers: [User]? = nil
    
    private var indexTitles: [String]? = nil
    private var indexedUsers: [[User]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        tableView.separatorStyle = .none
        tableView.register(R.nib.peerCell)
        tableView.register(PeerHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
        tableView.sectionIndexColor = R.color.text_tertiary()
        tableView.rowHeight = 70
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: UserDAO.usersDidChangeNotification, object: nil)
    }
    
    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        indexTitles?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        indexedUsers[section].count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
        let user = indexedUsers[indexPath.section][indexPath.row]
        cell.peerInfoView.render(user: user, description: .identityNumber)
        return cell
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        indexTitles
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        34
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID) as! PeerHeaderView
        header.label.text = indexTitles?[section]
        return header
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let explore = parent as? ExploreViewController else {
            return
        }
        let user = indexedUsers[indexPath.section][indexPath.row]
        explore.presentProfile(user: user)
    }
    
    @objc private func reloadData() {
        
        class ObjcAccessibleUser: NSObject {
            
            @objc let fullName: String
            let user: User
            
            init(user: User) {
                self.fullName = user.fullName ?? ""
                self.user = user
                super.init()
            }
            
        }
        
        DispatchQueue.global().async {
            let allUsers = UserDAO.shared.getAppUsers()
            let objcAccessibleUsers = allUsers.map(ObjcAccessibleUser.init(user:))
            let (titles, indexedObjcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let indexedUsers = indexedObjcUsers.map { $0.map(\.user) }
            DispatchQueue.main.async {
                self.allUsers = allUsers
                self.indexTitles = titles
                self.indexedUsers = indexedUsers
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: allUsers.count,
                                          text: R.string.localizable.no_bots(),
                                          photo: R.image.emptyIndicator.ic_data()!)
            }
        }
    }
    
}
