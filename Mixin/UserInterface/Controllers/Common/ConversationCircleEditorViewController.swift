import UIKit
import MixinServices

class ConversationCircleEditorViewController: UITableViewController {
    
    private let footerReuseId = "footer"
    
    private lazy var editNameController = EditNameController(presentingViewController: self)
    
    private var conversationId = ""
    private var embeddedCircle = CircleDAO.shared.embeddedCircles()
    private var subordinateCircles: [CircleItem] = []
    private var otherCircles: [CircleItem] = []
    
    class func instance(name: String, conversationId: String, subordinateCircles: [CircleItem]) -> UIViewController {
        let vc = ConversationCircleEditorViewController(style: .grouped)
        vc.conversationId = conversationId
        vc.subordinateCircles = subordinateCircles
        let title = R.string.localizable.circle_conversation_editor_title(name)
        return ContainerViewController.instance(viewController: vc, title: title)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableHeaderView = UIView()
        tableHeaderView.backgroundColor = .background
        tableHeaderView.frame.size.height = 15
        tableView.backgroundColor = .background
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = UIView()
        tableView.rowHeight = 80
        tableView.separatorStyle = .none
        tableView.register(R.nib.circleCell)
        tableView.register(ConversationCircleEditorFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
        reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: CircleDAO.circleDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
    }
    
    @objc func reloadData() {
        let conversationId = self.conversationId
        DispatchQueue.global().async { [weak self] in
            let allCircles = CircleDAO.shared.circles()
            let subordinateCircles = CircleDAO.shared.circles(of: conversationId)
            let otherCircles = allCircles.filter({ !subordinateCircles.contains($0) })
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.subordinateCircles = subordinateCircles
                self.otherCircles = otherCircles
                self.tableView.reloadData()
            }
        }
    }
    
}

extension ConversationCircleEditorViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return embeddedCircle.count + subordinateCircles.count
        } else {
            return otherCircles.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.circle, for: indexPath)!
        if indexPath.section == 0, indexPath.row < embeddedCircle.count {
            cell.titleLabel.text = "Mixin"
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count_all()
            cell.unreadMessageCountLabel.text = nil
            cell.circleImageView.image = R.image.ic_circle_all()
        } else {
            let circle: CircleItem
            if indexPath.section == 0 {
                circle = subordinateCircles[indexPath.row - embeddedCircle.count]
            } else {
                circle = otherCircles[indexPath.row]
            }
            cell.titleLabel.text = circle.name
            cell.subtitleLabel.text = R.string.localizable.circle_conversation_count("\(circle.conversationCount)")
            cell.unreadMessageCountLabel.text = nil
            cell.circleImageView.image = R.image.ic_circle_user()
        }
        cell.superscriptView.isHidden = true
        return cell
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
}

extension ConversationCircleEditorViewController {
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 0 ? 40 : .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! ConversationCircleEditorFooterView
            return view
        } else {
            return nil
        }
    }
    
}

extension ConversationCircleEditorViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let addCircle = R.string.localizable.circle_action_add()
        let add = R.string.localizable.action_add()
        editNameController.present(title: addCircle, actionTitle: add, currentName: nil) { (alert) in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            let vc = CircleEditorViewController.instance(name: name, intent: .create)
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_title_add()
    }
    
}
