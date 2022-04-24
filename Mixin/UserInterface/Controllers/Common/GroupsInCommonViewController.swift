import UIKit
import MixinServices

final class GroupsInCommonViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private var groupsInCommon = [GroupInCommon]()
    private var userId: String!
    
    class func instance(userId: String) -> UIViewController {
        let vc = GroupsInCommonViewController()
        vc.userId = userId
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.groups_In_Common())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(R.nib.groupInCommonCell)
        reloadData()
    }
    
}

extension GroupsInCommonViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupsInCommon.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.groups_in_common, for: indexPath)!
        cell.groupInCommon = groupsInCommon[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        DispatchQueue.global().async { [weak self] in
            guard
                let conversationId = self?.groupsInCommon[indexPath.row].conversationId,
                let conversation = ConversationDAO.shared.getConversation(conversationId: conversationId)
            else {
                return
            }
            DispatchQueue.main.async {
                let vc = ConversationViewController.instance(conversation: conversation)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
}

extension GroupsInCommonViewController {
    
    private func reloadData() {
        DispatchQueue.global().async {
            let groupsInCommon = ConversationDAO.shared.groupsInCommon(userId: self.userId)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.groupsInCommon = groupsInCommon
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: groupsInCommon.count,
                                          text: R.string.localizable.no_result(),
                                          photo: R.image.emptyIndicator.ic_search_result()!)
            }
        }
    }
    
}
