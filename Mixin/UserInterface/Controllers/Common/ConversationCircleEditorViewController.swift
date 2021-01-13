import UIKit
import MixinServices

class ConversationCircleEditorViewController: UITableViewController {
    
    private let footerReuseId = "footer"
    
    private lazy var editNameController = AlertEditorController(presentingViewController: self)
    private lazy var hintFooterView: UIView = {
        let view = R.nib.circlesTableFooterView(owner: nil)!
        view.label.text = R.string.localizable.circle_add_hint()
        view.buttonTopConstraint.constant = -80
        view.showsHintLabel = true
        view.button.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.contentView.snp.bottom)
        }
        view.button.setTitle(R.string.localizable.circle_action_add(), for: .normal)
        view.button.addTarget(self, action: #selector(addCircle(_:)), for: .touchUpInside)
        return view
    }()
    
    private var conversationId = ""
    private var ownerId: String?
    private var subordinateCircles: [CircleItem] = []
    private var otherCircles: [CircleItem] = []
    
    class func instance(name: String, conversationId: String, ownerId: String?, subordinateCircles: [CircleItem]) -> UIViewController {
        let vc = ConversationCircleEditorViewController(style: .grouped)
        vc.conversationId = conversationId
        vc.ownerId = ownerId
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
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: CircleConversationDAO.circleConversationsDidChangeNotification, object: nil)
    }
    
    @objc func reloadData() {
        let conversationId = self.conversationId
        let userId = self.ownerId
        DispatchQueue.global().async { [weak self] in
            let allCircles = CircleDAO.shared.circles()
            let subordinateCircles = CircleDAO.shared.circles(of: conversationId, userId: userId)
            let otherCircles = allCircles.filter({ !subordinateCircles.contains($0) })
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.subordinateCircles = subordinateCircles
                self.otherCircles = otherCircles
                self.tableView.tableFooterView = nil
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                if allCircles.isEmpty {
                    self.hintFooterView.frame.size.height = 300
                    self.tableView.tableFooterView = self.hintFooterView
                }
            }
        }
    }
    
    @objc func addCircle(_ sender: Any) {
        let addCircle = R.string.localizable.circle_action_add()
        let add = R.string.localizable.action_add()
        editNameController.present(title: addCircle, actionTitle: add) { (alert) in
            guard let name = alert.textFields?.first?.text else {
                return
            }
            self.performAddCircle(name: name)
        }
    }
    
    private func performAddCircle(name: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        CircleAPI.create(name: name) { (result) in
            switch result {
            case .success(let circle):
                DispatchQueue.global().async {
                    CircleDAO.shared.save(circle: circle)
                    self.addThisConversationIntoCircle(circleId: circle.circleId, hud: hud)
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
    private func addThisConversationIntoCircle(circleId: String, hud: Hud) {
        let completion = { [weak self] (result: MixinAPI.Result<[CircleConversation]>) in
            switch result {
            case .success(let objects):
                DispatchQueue.global().async {
                    CircleConversationDAO.shared.save(circleId: circleId, objects: objects)
                    DispatchQueue.main.sync {
                        self?.reloadData()
                        hud.set(style: .notification, text: R.string.localizable.toast_saved())
                        hud.scheduleAutoHidden()
                    }
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
        let requests = [ConversationCircleRequest(action: .ADD, circleId: circleId)]
        if let userId = ownerId {
            CircleAPI.updateCircles(forUserWith: userId, requests: requests, completion: completion)
        } else {
            CircleAPI.updateCircles(forConversationWith: conversationId, requests: requests, completion: completion)
        }
    }
    
}

extension ConversationCircleEditorViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return subordinateCircles.count
        } else {
            return otherCircles.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.circle, for: indexPath)!
        let circle: CircleItem
        if indexPath.section == 0 {
            circle = subordinateCircles[indexPath.row]
            cell.circleEditingStyle = .delete
        } else {
            circle = otherCircles[indexPath.row]
            cell.circleEditingStyle = .insert
        }
        cell.setImagePatternColor(id: circle.circleId)
        cell.titleLabel.text = circle.name
        cell.subtitleLabel.text = R.string.localizable.circle_conversation_count("\(circle.conversationCount)")
        cell.delegate = self
        cell.rightView.isHidden = true
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
        if section == 0 && !subordinateCircles.isEmpty && !otherCircles.isEmpty {
            return 40
        } else {
            return .leastNormalMagnitude
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 && !subordinateCircles.isEmpty && !otherCircles.isEmpty {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! ConversationCircleEditorFooterView
            return view
        } else {
            return nil
        }
    }
    
}

extension ConversationCircleEditorViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        addCircle(self)
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_title_add()
    }
    
}

extension ConversationCircleEditorViewController: CircleCellDelegate {
    
    func circleCellDidSelectEditingButton(_ cell: CircleCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let conversationId = self.conversationId
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let completion: (MixinAPI.Result<[CircleConversation]>) -> Void
        let requests: [ConversationCircleRequest]
        
        if indexPath.section == 0 {
            let circle = subordinateCircles[indexPath.row]
            requests = [ConversationCircleRequest(action: .REMOVE, circleId: circle.circleId)]
            completion = { (result) in
                switch result {
                case .success:
                    DispatchQueue.global().async {
                        CircleConversationDAO.shared.delete(circleId: circle.circleId,
                                                            conversationId: conversationId)
                        DispatchQueue.main.sync {
                            hud.set(style: .notification, text: R.string.localizable.toast_saved())
                            hud.scheduleAutoHidden()
                            if let index = self.subordinateCircles.firstIndex(where: { $0.circleId == circle.circleId }) {
                                let circle = self.subordinateCircles.remove(at: index)
                                circle.conversationCount -= 1
                                self.otherCircles.insert(circle, at: 0)
                            }
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        } else {
            let circle = otherCircles[indexPath.row]
            requests = [ConversationCircleRequest(action: .ADD, circleId: circle.circleId)]
            completion = { (result) in
                switch result {
                case .success(let objects):
                    DispatchQueue.global().async {
                        CircleConversationDAO.shared.save(circleId: circle.circleId, objects: objects)
                        DispatchQueue.main.sync {
                            hud.set(style: .notification, text: R.string.localizable.toast_saved())
                            hud.scheduleAutoHidden()
                            if let index = self.otherCircles.firstIndex(where: { $0.circleId == circle.circleId }) {
                                let circle = self.otherCircles.remove(at: index)
                                circle.conversationCount += 1
                                self.subordinateCircles.append(circle)
                            }
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    hud.set(style: .error, text: error.localizedDescription)
                    hud.scheduleAutoHidden()
                }
            }
        }
        
        if let userId = ownerId {
            CircleAPI.updateCircles(forUserWith: userId, requests: requests, completion: completion)
        } else {
            CircleAPI.updateCircles(forConversationWith: conversationId, requests: requests, completion: completion)
        }
    }
    
}
